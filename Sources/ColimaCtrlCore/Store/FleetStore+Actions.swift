import Foundation

public enum ContainerAction: String, Sendable {
    case start, stop, restart

    var pendingOp: PendingOp {
        switch self {
        case .start: .starting
        case .stop: .stopping
        case .restart: .restarting
        }
    }
}

public enum PendingOp: Sendable {
    case starting, stopping, restarting, removing, pruning

    public var label: String {
        switch self {
        case .starting: "Starting…"
        case .stopping: "Stopping…"
        case .restarting: "Restarting…"
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
                for id in ids { group.addTask { try await client.send("POST", "/containers/\(id)/\(action.rawValue)") } }
                try await group.waitForAll()
            }
        }
    }

    public var runningIDs: [String] { containers.filter { $0.isRunning }.map(\.id) }

    public func stopAllRunning() {
        perform(.stop, on: runningIDs)
    }

    public func perform(_ action: ContainerAction, project: String) {
        perform(action, on: containers.filter { $0.project == project }.map(\.id))
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
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        run("Remove volume \(name)") { try await $0.send("DELETE", "/volumes/\(encoded)") }
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

    public func remove(network id: String) {
        run("Remove network") { try await $0.send("DELETE", "/networks/\(id)") }
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
