import Foundation

public enum ContainerAction: String, Sendable {
    case start, stop, restart, pause, resume

    var endpoint: String { self == .resume ? "unpause" : rawValue }

    var pendingOp: PendingOp {
        switch self {
        case .start: .starting
        case .stop: .stopping
        case .restart: .restarting
        case .pause: .pausing
        case .resume: .resuming
        }
    }
}

public enum PendingOp: Sendable {
    case starting, stopping, restarting, pausing, resuming, removing, pruning

    public var label: String {
        switch self {
        case .starting: "Starting…"
        case .stopping: "Stopping…"
        case .restarting: "Restarting…"
        case .pausing: "Pausing…"
        case .resuming: "Resuming…"
        case .removing: "Removing…"
        case .pruning: "Pruning…"
        }
    }
}

public enum PruneKind: String, Sendable {
    case containers, imagesDangling, imagesUnused, volumes, buildCache

    public var pendingKey: String { "prune:\(rawValue)" }

    var path: String {
        func filter(_ json: String) -> String { json.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
        switch self {
        case .containers: return "/containers/prune"
        case .imagesDangling: return "/images/prune"
        case .imagesUnused: return "/images/prune?filters=" + filter(#"{"dangling":["false"]}"#)
        case .volumes: return "/volumes/prune?filters=" + filter(#"{"all":["true"]}"#)
        case .buildCache: return "/build/prune?all=true"
        }
    }
}

extension FleetStore {
    public func perform(_ action: ContainerAction, on ids: [String]) {
        guard !ids.isEmpty else { return }
        run("\(action.rawValue.capitalized) \(describe(ids))", marking: ids, as: action.pendingOp) { client in
            try await withThrowingTaskGroup(of: Void.self) { group in
                for id in ids { group.addTask { try await client.send("POST", "/containers/\(id)/\(action.endpoint)") } }
                try await group.waitForAll()
            }
        }
    }

    public var runningIDs: [String] { containers.filter { $0.isRunning }.map(\.id) }

    public func stopAllRunning() {
        perform(.stop, on: runningIDs)
    }

    /// A nil project means the containers that belong to no Compose project.
    public func perform(_ action: ContainerAction, project: String?) {
        perform(action, on: containers.filter { $0.project == project }.map(\.id))
    }

    public func rename(container id: String, to name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        run("Rename to \(name)") { try await $0.send("POST", "/containers/\(id)/rename?name=\(encoded)") }
    }

    public func remove(container id: String) {
        remove(containers: [id])
    }

    public func remove(containers ids: [String]) {
        guard !ids.isEmpty else { return }
        run("Remove \(describe(ids))", marking: ids, as: .removing) { client in
            try await withThrowingTaskGroup(of: Void.self) { group in
                for id in ids { group.addTask { try await client.send("DELETE", "/containers/\(id)?force=1") } }
                try await group.waitForAll()
            }
        }
    }

    public func remove(image id: String) {
        run("Remove image") { try await $0.send("DELETE", "/images/\(id)") }
    }

    public func remove(volume name: String) {
        run("Remove volume \(name)") { try await $0.send("DELETE", Self.volumePath(name)) }
    }

    /// Pulls an image, reporting progress as the engine streams it, then refreshes the image list.
    public func pull(image reference: ImageReference, onProgress: @MainActor (PullProgress) -> Void) async throws {
        var progress = PullProgress()
        var splitter = LineSplitter()
        onProgress(progress)
        for try await chunk in client.stream("POST", "/images/create?\(reference.query)") {
            for line in splitter.feed(chunk) { progress.feed(line) }
            onProgress(progress)
        }
        if let message = progress.error { throw DockerError.http(status: 500, message: message) }
        heavyPending = true
        await refresh(heavy: true)
    }

    public func prune(_ kind: PruneKind) {
        run("Prune", marking: [kind.pendingKey], as: .pruning) { try await $0.send("POST", kind.path) }
    }

    public func inspectVolume(_ name: String) async throws -> VolumeDetail {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return VolumeDetail(try await client.get("/volumes/\(encoded)", as: APIVolumeInspect.self))
    }

    public func inspectImage(_ id: String) async throws -> ImageDetail {
        ImageDetail(try await client.get("/images/\(id)/json", as: APIImageInspect.self))
    }

    public func inspectNetwork(_ id: String) async throws -> NetworkDetail {
        NetworkDetail(try await client.get("/networks/\(id)", as: APINetworkInspect.self))
    }

    public func remove(volumes names: [String]) {
        guard !names.isEmpty else { return }
        run("Remove \(names.count) volumes") { try await Self.deleteAll(names.map(Self.volumePath), client: $0) }
    }

    public func remove(images ids: [String]) {
        guard !ids.isEmpty else { return }
        run("Remove \(ids.count) images") { try await Self.deleteAll(ids.map { "/images/\($0)" }, client: $0) }
    }

    public func remove(networks ids: [String]) {
        guard !ids.isEmpty else { return }
        run("Remove \(ids.count) networks") { try await Self.deleteAll(ids.map { "/networks/\($0)" }, client: $0) }
    }

    nonisolated static func volumePath(_ name: String) -> String {
        "/volumes/" + (name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)
    }

    /// Sends every delete even when one fails, then reports the first failure.
    nonisolated static func deleteAll(_ paths: [String], client: DockerClient) async throws {
        let failures = await withTaskGroup(of: String?.self) { group in
            for path in paths {
                group.addTask {
                    do { try await client.send("DELETE", path); return nil } catch { return error.localizedDescription }
                }
            }
            var messages: [String] = []
            for await message in group { if let message { messages.append(message) } }
            return messages
        }
        if let first = failures.first {
            throw DockerError.http(status: 409, message: failures.count == 1 && paths.count == 1 ? first : "\(failures.count) of \(paths.count) failed: \(first)")
        }
    }

    public func remove(network id: String) {
        run("Remove network") { try await $0.send("DELETE", "/networks/\(id)") }
    }

    /// The engine's inspect JSON, indented with sorted keys for pasting into a ticket or a diff.
    public func inspectJSON(_ id: String) async throws -> String {
        let data = try await client.getData("/containers/\(id)/json")
        let object = try JSONSerialization.jsonObject(with: data)
        let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: pretty, as: UTF8.self)
    }

    public func cachedInspect(_ id: String) -> ContainerInspect? { inspectCache[id] }

    public func inspect(_ id: String) async throws -> ContainerInspect {
        let result = ContainerInspect(try await client.get("/containers/\(id)/json", as: APIInspect.self))
        inspectCache[id] = result
        return result
    }

    private func describe(_ ids: [String]) -> String {
        guard ids.count == 1, let id = ids.first else { return "\(ids.count) containers" }
        return containers.first { $0.id == id }?.name ?? id
    }

    /// Marks `keys` pending until the follow-up refresh lands; a 30 s timeout clears the marks if an event is lost.
    private func run(_ label: String, marking keys: [String] = [], as op: PendingOp = .stopping, _ work: @escaping @Sendable (DockerClient) async throws -> Void) {
        for key in keys { pending[key] = op }
        Task { [client] in
            let timeout = Task { [weak self] in
                try await Task.sleep(for: .seconds(30))
                self?.clearPending(keys)
            }
            do { try await work(client) } catch { lastError = "\(label): \(error.localizedDescription)" }
            heavyPending = true
            await refresh(heavy: true)
            timeout.cancel()
            clearPending(keys)
        }
    }

    private func clearPending(_ keys: [String]) {
        for key in keys { pending[key] = nil }
    }
}
