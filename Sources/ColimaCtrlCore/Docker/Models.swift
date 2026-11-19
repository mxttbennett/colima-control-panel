import Foundation

public enum DisplayState: Sendable, Equatable {
    case running, starting, restarting, unhealthy, paused, stopped
}

extension DisplayState {
    public var label: String {
        switch self {
        case .running: "Running"
        case .starting: "Starting"
        case .restarting: "Restarting"
        case .unhealthy: "Unhealthy"
        case .paused: "Paused"
        case .stopped: "Stopped"
        }
    }
}

public struct ContainerRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let image: String
    public let imageID: String
    public let volumes: [String]
    public let state: String
    public let status: String
    public let health: String?
    public let project: String?
    public let service: String?
    public let projectDirectory: String?
    public let ports: [Int]
    public let portMappings: [PortMapping]
    public let networks: [String]
    public let created: Date
    public var startedAt: Date?

    public var isRunning: Bool { state == "running" || state == "restarting" || state == "paused" }
    public var isPaused: Bool { state == "paused" }
    public var canPause: Bool { state == "running" }
    public var title: String { service ?? name }

    public var exitCode: Int? {
        guard status.hasPrefix("Exited ("), let close = status.firstIndex(of: ")") else { return nil }
        return Int(status[status.index(status.startIndex, offsetBy: 8)..<close])
    }

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
    private static func mappings(_ ports: [APIContainer.Port]) -> [PortMapping] {
        let all = ports.compactMap { port -> PortMapping? in
            guard let host = port.publicPort, let container = port.privatePort else { return nil }
            return PortMapping(host: host, container: container, proto: port.type ?? "tcp")
        }
        return Array(Set(all)).sorted { ($0.host, $0.container) < ($1.host, $1.container) }
    }

    init(_ api: APIContainer, startedAt: Date?) {
        let labels = api.labels ?? [:]
        let health = ["healthy", "unhealthy", "health: starting"].first { api.status.contains("(\($0))") }
        self.init(
            id: api.id,
            name: (api.names.first ?? api.id).trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            image: api.image,
            imageID: api.imageID ?? "",
            volumes: (api.mounts ?? []).compactMap { $0.type == "volume" ? $0.name : nil },
            state: api.state,
            status: api.status,
            health: health == "health: starting" ? "starting" : health,
            project: labels["com.docker.compose.project"],
            service: labels["com.docker.compose.service"],
            projectDirectory: labels["com.docker.compose.project.working_dir"],
            ports: Array(Set((api.ports ?? []).compactMap(\.publicPort))).sorted(),
            portMappings: Self.mappings(api.ports ?? []),
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
    public var subnetKey: String { subnet ?? "" }
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
    public var reclaimable: Int64 { images.reclaimable + containers.reclaimable + volumes.reclaimable + buildCache.reclaimable }
}

public struct HealthCheck: Equatable, Sendable {
    public let date: Date?
    public let exitCode: Int
    public let output: String
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
    public let failingStreak: Int
    /// The engine keeps the last few checks, newest last.
    public let healthChecks: [HealthCheck]
    public let env: [(key: String, value: String)]
    public let mounts: [Mount]
    public let ports: [PortBinding]
    public let attachments: [Attachment]
    public let labels: [KeyValue]
    public let restartCount: Int
    public let exitCode: Int?
    public let oomKilled: Bool
    public let memoryLimit: Int64?
    public let cpuLimit: Double?

    /// `KEY=value` lines, the format `docker run --env-file` reads.
    public static func envFile(_ pairs: [(key: String, value: String)]) -> String {
        pairs.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
    }

    public static func == (lhs: ContainerInspect, rhs: ContainerInspect) -> Bool {
        lhs.id == rhs.id && lhs.image == rhs.image && lhs.command == rhs.command && lhs.health == rhs.health
            && lhs.failingStreak == rhs.failingStreak && lhs.healthChecks == rhs.healthChecks
            && lhs.mounts == rhs.mounts && lhs.ports == rhs.ports && lhs.attachments == rhs.attachments
            && lhs.memoryLimit == rhs.memoryLimit && lhs.cpuLimit == rhs.cpuLimit && lhs.labels == rhs.labels && lhs.restartCount == rhs.restartCount && lhs.exitCode == rhs.exitCode && lhs.oomKilled == rhs.oomKilled
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
            failingStreak: api.state.health?.failingStreak ?? 0,
            healthChecks: (api.state.health?.log ?? []).map {
                HealthCheck(date: $0.end.flatMap(DockerDate.parse), exitCode: $0.exitCode ?? 0, output: ($0.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            },
            env: (api.config.env ?? []).map { line in
                let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
            },
            mounts: (api.mounts ?? []).map { Mount(type: $0.type, source: $0.name ?? $0.source ?? "", destination: $0.destination, readOnly: $0.rw == false) },
            ports: Array(Set(bindings.map(\.id)).compactMap { id in bindings.first { $0.id == id } }).sorted { $0.id < $1.id },
            attachments: (api.networkSettings?.networks ?? [:]).map { Attachment(network: $0.key, address: $0.value.ipAddress ?? "") }.sorted { $0.network < $1.network },
            labels: (api.config.labels ?? [:]).map { KeyValue(key: $0.key, value: $0.value) }.sorted { $0.key < $1.key },
            restartCount: api.restartCount ?? 0,
            exitCode: api.state.exitCode,
            oomKilled: api.state.oomKilled ?? false,
            memoryLimit: api.hostConfig?.memory.flatMap { $0 > 0 ? $0 : nil },
            cpuLimit: api.hostConfig?.nanoCpus.flatMap { $0 > 0 ? Double($0) / 1e9 : nil }
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

public struct KeyValue: Equatable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let value: String
}

public struct VolumeDetail: Equatable, Sendable {
    public let driver: String
    public let scope: String
    public let mountpoint: String
    public let created: Date?
    public let labels: [KeyValue]
}

public struct ImageDetail: Equatable, Sendable {
    public let digest: String
    public let created: Date?
    public let architecture: String
    public let os: String
    public let entrypoint: String
    public let command: String
    public let exposedPorts: [String]
    public let env: [KeyValue]
}

public struct NetworkDetail: Equatable, Sendable {
    public struct Member: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let address: String
    }
    public let driver: String
    public let scope: String
    public let created: Date?
    public let isInternal: Bool
    public let ipv6: Bool
    public let subnet: String?
    public let gateway: String?
    public let members: [Member]
}

private func pairs(_ lines: [String]) -> [KeyValue] {
    lines.map { line in
        let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        return KeyValue(key: String(parts[0]), value: parts.count > 1 ? String(parts[1]) : "")
    }
}

extension VolumeDetail {
    init(_ api: APIVolumeInspect) {
        self.init(
            driver: api.driver ?? "local", scope: api.scope ?? "local", mountpoint: api.mountpoint ?? "",
            created: api.createdAt.flatMap(DockerDate.parse),
            labels: (api.labels ?? [:]).map { KeyValue(key: $0.key, value: $0.value) }.sorted { $0.key < $1.key }
        )
    }
}

extension ImageDetail {
    init(_ api: APIImageInspect) {
        self.init(
            digest: api.repoDigests?.first ?? "", created: api.created.flatMap(DockerDate.parse),
            architecture: api.architecture ?? "", os: api.os ?? "",
            entrypoint: (api.config?.entrypoint ?? []).joined(separator: " "), command: (api.config?.cmd ?? []).joined(separator: " "),
            exposedPorts: (api.config?.exposedPorts ?? [:]).keys.sorted(), env: pairs(api.config?.env ?? [])
        )
    }
}

extension NetworkDetail {
    init(_ api: APINetworkInspect) {
        let config = api.ipam?.config?.first
        self.init(
            driver: api.driver ?? "", scope: api.scope ?? "", created: api.created.flatMap(DockerDate.parse),
            isInternal: api.isInternal ?? false, ipv6: api.enableIPv6 ?? false, subnet: config?.subnet, gateway: config?.gateway,
            members: (api.containers ?? [:]).map { Member(id: $0.key, name: $0.value.name ?? String($0.key.prefix(12)), address: $0.value.ipv4 ?? "") }.sorted { $0.name < $1.name }
        )
    }
}
