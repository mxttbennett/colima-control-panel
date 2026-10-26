import Foundation

public enum ContainerAction: String, Sendable { case start, stop, restart }

public enum PruneKind: Sendable {
    case containers, imagesDangling, imagesUnused, volumes, buildCache

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
        run { client in
            try await withThrowingTaskGroup(of: Void.self) { group in
                for id in ids { group.addTask { try await client.send("POST", "/containers/\(id)/\(action.rawValue)") } }
                try await group.waitForAll()
            }
        }
    }

    public func perform(_ action: ContainerAction, project: String) {
        perform(action, on: containers.filter { $0.project == project }.map(\.id))
    }

    public func remove(container id: String) {
        run { try await $0.send("DELETE", "/containers/\(id)?force=1") }
    }

    public func remove(image id: String) {
        run { try await $0.send("DELETE", "/images/\(id)") }
    }

    public func remove(volume name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        run { try await $0.send("DELETE", "/volumes/\(encoded)") }
    }

    public func prune(_ kind: PruneKind) {
        run { try await $0.send("POST", kind.path) }
    }

    public func cachedInspect(_ id: String) -> ContainerInspect? { inspectCache[id] }

    public func inspect(_ id: String) async throws -> ContainerInspect {
        let result = ContainerInspect(try await client.get("/containers/\(id)/json", as: APIInspect.self))
        inspectCache[id] = result
        return result
    }

    private func run(_ work: @escaping @Sendable (DockerClient) async throws -> Void) {
        Task { [client] in
            do { try await work(client) } catch { lastError = error.localizedDescription }
            heavyPending = true
            scheduleRefresh(after: .milliseconds(100))
        }
    }
}
