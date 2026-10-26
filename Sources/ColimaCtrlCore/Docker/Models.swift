import Foundation

public enum DisplayState: Sendable, Equatable {
    case running, starting, restarting, unhealthy, paused, stopped
}

public struct ContainerRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let image: String
    public let state: String
    public let status: String
    public let health: String?
    public let project: String?
    public let service: String?
    public let ports: [Int]
    public let networks: [String]
    public let created: Date
    public var startedAt: Date?

    public var isRunning: Bool { state == "running" || state == "restarting" || state == "paused" }
    public var title: String { service ?? name }

    public var display: DisplayState {
        switch state {
        case "restarting": .restarting
        case "paused": .paused
        case "running":
            switch health {
            case "unhealthy": .unhealthy
            case "starting": .starting
            default: .running
            }
        default: .stopped
        }
    }
}

extension ContainerRow {
    init(_ api: APIContainer, startedAt: Date?) {
        let labels = api.labels ?? [:]
        let health = ["healthy", "unhealthy", "health: starting"].first { api.status.contains("(\($0))") }
        self.init(
            id: api.id,
            name: (api.names.first ?? api.id).trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            image: api.image,
            state: api.state,
            status: api.status,
            health: health == "health: starting" ? "starting" : health,
            project: labels["com.docker.compose.project"],
            service: labels["com.docker.compose.service"],
            ports: Array(Set((api.ports ?? []).compactMap(\.publicPort))).sorted(),
            networks: (api.networkSettings?.networks.map { Array($0.keys) } ?? []).sorted(),
            created: Date(timeIntervalSince1970: TimeInterval(api.created)),
            startedAt: api.state == "running" ? startedAt : nil
        )
    }
}

public enum FleetHealth: Sendable, Equatable {
    case idle, healthy, starting, unhealthy

    /// Worst state across running containers: unhealthy beats starting beats healthy.
    public init(_ containers: [ContainerRow]) {
        let states = containers.filter(\.isRunning).map(\.display)
        if states.isEmpty { self = .idle }
        else if states.contains(.unhealthy) { self = .unhealthy }
        else if states.contains(where: { $0 == .starting || $0 == .restarting }) { self = .starting }
        else { self = .healthy }
    }
}

public struct EngineInfo: Equatable, Sendable {
    public let cpus: Int
    public let memory: Int64
    public let version: String
    public let name: String
}

public struct ImageRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let tags: [String]
    public let size: Int64
    public let created: Date
    public let containers: Int

    public var title: String { tags.isEmpty ? "<none> " + id.replacingOccurrences(of: "sha256:", with: "").prefix(12) : tags.joined(separator: ", ") }
}

public struct VolumeRow: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let size: Int64
    public let refs: Int
    public let project: String?
}

public struct NetworkRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let driver: String
    public let scope: String
    public let isInternal: Bool
    public let subnet: String?

    public var isBuiltIn: Bool { ["bridge", "host", "none"].contains(name) }
}

public struct DiskBucket: Equatable, Sendable {
    public let count: Int
    public let size: Int64
    public let reclaimable: Int64
}

public struct DiskUsage: Equatable, Sendable {
    public let images: DiskBucket
    public let containers: DiskBucket
    public let volumes: DiskBucket
    public let buildCache: DiskBucket

    public var total: Int64 { images.size + containers.size + volumes.size + buildCache.size }
}

public struct ContainerInspect: Equatable, Sendable {
    public struct Mount: Equatable, Sendable, Identifiable {
        public var id: String { destination }
        public let type: String
        public let source: String
        public let destination: String
        public let readOnly: Bool
    }
    public struct PortBinding: Equatable, Sendable, Identifiable {
        public var id: String { "\(container):\(host)" }
        public let container: String
        public let host: Int
    }
    public struct Attachment: Equatable, Sendable, Identifiable {
        public var id: String { network }
        public let network: String
        public let address: String
    }

    public let id: String
    public let image: String
    public let command: String
    public let created: Date?
    public let restartPolicy: String
    public let health: String?
    public let env: [(key: String, value: String)]
    public let mounts: [Mount]
    public let ports: [PortBinding]
    public let attachments: [Attachment]

    public static func == (lhs: ContainerInspect, rhs: ContainerInspect) -> Bool {
        lhs.id == rhs.id && lhs.image == rhs.image && lhs.command == rhs.command && lhs.health == rhs.health
            && lhs.mounts == rhs.mounts && lhs.ports == rhs.ports && lhs.attachments == rhs.attachments
            && lhs.env.map { "\($0.key)=\($0.value)" } == rhs.env.map { "\($0.key)=\($0.value)" }
    }
}

extension ContainerInspect {
    init(_ api: APIInspect) {
        let bindings = (api.networkSettings?.ports ?? [:]).flatMap { container, bindings in
            (bindings ?? []).compactMap { $0.hostPort.flatMap(Int.init).map { PortBinding(container: container, host: $0) } }
        }
        self.init(
            id: api.id,
            image: api.config.image,
            command: ([api.path] + (api.args ?? [])).joined(separator: " "),
            created: DockerDate.parse(api.created),
            restartPolicy: api.hostConfig?.restartPolicy?.name.nilIfEmpty ?? "no",
            health: api.state.health?.status,
            env: (api.config.env ?? []).map { line in
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
            },
            mounts: (api.mounts ?? []).map { Mount(type: $0.type, source: $0.name ?? $0.source ?? "", destination: $0.destination, readOnly: $0.rw == false) },
            ports: Array(Set(bindings.map(\.id)).compactMap { id in bindings.first { $0.id == id } }).sorted { $0.id < $1.id },
            attachments: (api.networkSettings?.networks ?? [:]).map { Attachment(network: $0.key, address: $0.value.ipAddress ?? "") }.sorted { $0.network < $1.network }
        )
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

public enum DockerDate {
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    /// Docker emits nanoseconds; the formatter accepts at most milliseconds.
    public static func parse(_ text: String) -> Date? {
        guard let dot = text.firstIndex(of: "."), let zone = text.lastIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }), dot < zone else {
            return plain.date(from: text)
        }
        let fraction = text[text.index(after: dot)..<zone].prefix(3)
        return formatter.date(from: text[text.startIndex..<dot] + "." + fraction + text[zone...])
    }
}

public struct StatsSample: Sendable, Equatable {
    public let containerTotal: UInt64
    public let systemTotal: UInt64
    public let cpus: Int
    public let memory: UInt64
    public let memoryLimit: UInt64

    /// CPU as a percentage of one core, from two successive samples.
    public func cpuPercent(since previous: StatsSample) -> Double {
        let containerDelta = Double(containerTotal) - Double(previous.containerTotal)
        let systemDelta = Double(systemTotal) - Double(previous.systemTotal)
        guard systemDelta > 0, containerDelta >= 0 else { return 0 }
        return containerDelta / systemDelta * Double(cpus) * 100
    }
}

extension StatsSample {
    /// The engine's own previous sample, present when the request was not one-shot.
    init?(previousOf api: APIStats) {
        guard let pre = api.precpu, let system = pre.system, system > 0 else { return nil }
        self.init(containerTotal: pre.usage.total, systemTotal: system, cpus: api.cpu.online ?? 1, memory: 0, memoryLimit: 0)
    }

    init(_ api: APIStats) {
        let reclaimable = api.memory?.stats?["inactive_file"] ?? api.memory?.stats?["cache"] ?? 0
        let usage = api.memory?.usage ?? 0
        self.init(
            containerTotal: api.cpu.usage.total,
            systemTotal: api.cpu.system ?? 0,
            cpus: api.cpu.online ?? 1,
            memory: usage > reclaimable ? usage - reclaimable : 0,
            memoryLimit: api.memory?.limit ?? 0
        )
    }
}
