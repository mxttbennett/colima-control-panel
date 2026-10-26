import Foundation

struct Empty: Decodable, Sendable {}

struct APIContainer: Decodable, Sendable {
    struct Port: Decodable, Sendable {
        let publicPort: Int?
        enum CodingKeys: String, CodingKey { case publicPort = "PublicPort" }
    }
    struct NetworkSettings: Decodable, Sendable {
        let networks: [String: Empty]?
        enum CodingKeys: String, CodingKey { case networks = "Networks" }
    }
    struct Mount: Decodable, Sendable {
        let type: String?
        let name: String?
        enum CodingKeys: String, CodingKey { case type = "Type", name = "Name" }
    }
    let id: String
    let names: [String]
    let image: String
    let imageID: String?
    let mounts: [Mount]?
    let state: String
    let status: String
    let created: Int
    let labels: [String: String]?
    let ports: [Port]?
    let networkSettings: NetworkSettings?
    enum CodingKeys: String, CodingKey {
        case id = "Id", names = "Names", image = "Image", imageID = "ImageID", mounts = "Mounts", state = "State", status = "Status", created = "Created"
        case labels = "Labels", ports = "Ports", networkSettings = "NetworkSettings"
    }
}

struct APIInfo: Decodable, Sendable {
    let cpus: Int
    let memory: Int64
    let version: String
    let name: String
    enum CodingKeys: String, CodingKey { case cpus = "NCPU", memory = "MemTotal", version = "ServerVersion", name = "Name" }
}

struct APINetwork: Decodable, Sendable {
    struct IPAM: Decodable, Sendable {
        struct Config: Decodable, Sendable {
            let subnet: String?
            enum CodingKeys: String, CodingKey { case subnet = "Subnet" }
        }
        let config: [Config]?
        enum CodingKeys: String, CodingKey { case config = "Config" }
    }
    let id: String
    let name: String
    let driver: String
    let scope: String
    let isInternal: Bool?
    let ipam: IPAM?
    enum CodingKeys: String, CodingKey {
        case id = "Id", name = "Name", driver = "Driver", scope = "Scope", isInternal = "Internal", ipam = "IPAM"
    }
}

struct APIDf: Decodable, Sendable {
    struct Usage<Item: Decodable & Sendable>: Decodable, Sendable {
        let items: [Item]?
        enum CodingKeys: String, CodingKey { case items = "Items" }
    }
    struct Image: Decodable, Sendable {
        let id: String
        let repoTags: [String]?
        let size: Int64
        let created: Int
        let containers: Int?
        enum CodingKeys: String, CodingKey { case id = "Id", repoTags = "RepoTags", size = "Size", created = "Created", containers = "Containers" }
    }
    struct Volume: Decodable, Sendable {
        struct UsageData: Decodable, Sendable {
            let size: Int64?
            let refCount: Int?
            enum CodingKeys: String, CodingKey { case size = "Size", refCount = "RefCount" }
        }
        let name: String
        let labels: [String: String]?
        let usageData: UsageData?
        enum CodingKeys: String, CodingKey { case name = "Name", labels = "Labels", usageData = "UsageData" }
    }
    struct CacheEntry: Decodable, Sendable {
        let size: Int64
        let inUse: Bool?
        enum CodingKeys: String, CodingKey { case size = "Size", inUse = "InUse" }
    }
    struct ContainerEntry: Decodable, Sendable {
        let state: String?
        let sizeRw: Int64?
        enum CodingKeys: String, CodingKey { case state = "State", sizeRw = "SizeRw" }
    }

    let images: [Image]?
    let volumes: [Volume]?
    let buildCache: [CacheEntry]?
    let containers: [ContainerEntry]?
    let imageUsage: Usage<Image>?
    let volumeUsage: Usage<Volume>?
    let buildCacheUsage: Usage<CacheEntry>?
    let containerUsage: Usage<ContainerEntry>?
    enum CodingKeys: String, CodingKey {
        case images = "Images", volumes = "Volumes", buildCache = "BuildCache", containers = "Containers"
        case imageUsage = "ImageUsage", volumeUsage = "VolumeUsage", buildCacheUsage = "BuildCacheUsage", containerUsage = "ContainerUsage"
    }

    // Engines before API 1.52 return flat arrays; newer ones nest them under *Usage.Items.
    var allImages: [Image] { imageUsage?.items ?? images ?? [] }
    var allVolumes: [Volume] { volumeUsage?.items ?? volumes ?? [] }
    var allCache: [CacheEntry] { buildCacheUsage?.items ?? buildCache ?? [] }
    var allContainers: [ContainerEntry] { containerUsage?.items ?? containers ?? [] }
}

struct APIInspect: Decodable, Sendable {
    struct Config: Decodable, Sendable {
        let image: String
        let env: [String]?
        enum CodingKeys: String, CodingKey { case image = "Image", env = "Env" }
    }
    struct State: Decodable, Sendable {
        struct Health: Decodable, Sendable {
            let status: String
            enum CodingKeys: String, CodingKey { case status = "Status" }
        }
        let startedAt: String
        let health: Health?
        enum CodingKeys: String, CodingKey { case startedAt = "StartedAt", health = "Health" }
    }
    struct HostConfig: Decodable, Sendable {
        struct Restart: Decodable, Sendable {
            let name: String
            enum CodingKeys: String, CodingKey { case name = "Name" }
        }
        let restartPolicy: Restart?
        enum CodingKeys: String, CodingKey { case restartPolicy = "RestartPolicy" }
    }
    struct Mount: Decodable, Sendable {
        let type: String
        let name: String?
        let source: String?
        let destination: String
        let rw: Bool?
        enum CodingKeys: String, CodingKey { case type = "Type", name = "Name", source = "Source", destination = "Destination", rw = "RW" }
    }
    struct NetworkSettings: Decodable, Sendable {
        struct Binding: Decodable, Sendable {
            let hostPort: String?
            enum CodingKeys: String, CodingKey { case hostPort = "HostPort" }
        }
        struct Attachment: Decodable, Sendable {
            let ipAddress: String?
            enum CodingKeys: String, CodingKey { case ipAddress = "IPAddress" }
        }
        let ports: [String: [Binding]?]?
        let networks: [String: Attachment]?
        enum CodingKeys: String, CodingKey { case ports = "Ports", networks = "Networks" }
    }
    let id: String
    let created: String
    let path: String
    let args: [String]?
    let config: Config
    let state: State
    let hostConfig: HostConfig?
    let mounts: [Mount]?
    let networkSettings: NetworkSettings?
    enum CodingKeys: String, CodingKey {
        case id = "Id", created = "Created", path = "Path", args = "Args", config = "Config", state = "State"
        case hostConfig = "HostConfig", mounts = "Mounts", networkSettings = "NetworkSettings"
    }
}

struct APIStats: Decodable, Sendable {
    struct CPU: Decodable, Sendable {
        struct Usage: Decodable, Sendable {
            let total: UInt64
            enum CodingKeys: String, CodingKey { case total = "total_usage" }
        }
        let usage: Usage
        let system: UInt64?
        let online: Int?
        enum CodingKeys: String, CodingKey { case usage = "cpu_usage", system = "system_cpu_usage", online = "online_cpus" }
    }
    struct Memory: Decodable, Sendable {
        let usage: UInt64?
        let limit: UInt64?
        let stats: [String: UInt64]?
    }
    let cpu: CPU
    let precpu: CPU?
    let memory: Memory?
    enum CodingKeys: String, CodingKey { case cpu = "cpu_stats", precpu = "precpu_stats", memory = "memory_stats" }
}

struct APITtyProbe: Decodable, Sendable {
    struct Config: Decodable, Sendable {
        let tty: Bool?
        enum CodingKeys: String, CodingKey { case tty = "Tty" }
    }
    let config: Config
    enum CodingKeys: String, CodingKey { case config = "Config" }
}

struct APIEvent: Decodable, Sendable {
    struct Actor: Decodable, Sendable {
        let id: String?
        enum CodingKeys: String, CodingKey { case id = "ID" }
    }
    let type: String
    let action: String
    let actor: Actor?
    enum CodingKeys: String, CodingKey { case type = "Type", action = "Action", actor = "Actor" }
}

struct APIVolumeInspect: Decodable, Sendable {
    let name: String
    let driver: String?
    let scope: String?
    let mountpoint: String?
    let createdAt: String?
    let labels: [String: String]?
    enum CodingKeys: String, CodingKey {
        case name = "Name", driver = "Driver", scope = "Scope", mountpoint = "Mountpoint", createdAt = "CreatedAt", labels = "Labels"
    }
}

struct APIImageInspect: Decodable, Sendable {
    struct Config: Decodable, Sendable {
        let entrypoint: [String]?
        let cmd: [String]?
        let env: [String]?
        let exposedPorts: [String: Empty]?
        enum CodingKeys: String, CodingKey { case entrypoint = "Entrypoint", cmd = "Cmd", env = "Env", exposedPorts = "ExposedPorts" }
    }
    let id: String
    let repoTags: [String]?
    let repoDigests: [String]?
    let created: String?
    let size: Int64?
    let architecture: String?
    let os: String?
    let config: Config?
    enum CodingKeys: String, CodingKey {
        case id = "Id", repoTags = "RepoTags", repoDigests = "RepoDigests", created = "Created", size = "Size"
        case architecture = "Architecture", os = "Os", config = "Config"
    }
}

struct APINetworkInspect: Decodable, Sendable {
    struct Attached: Decodable, Sendable {
        let name: String?
        let ipv4: String?
        enum CodingKeys: String, CodingKey { case name = "Name", ipv4 = "IPv4Address" }
    }
    struct IPAM: Decodable, Sendable {
        struct Config: Decodable, Sendable {
            let subnet: String?
            let gateway: String?
            enum CodingKeys: String, CodingKey { case subnet = "Subnet", gateway = "Gateway" }
        }
        let config: [Config]?
        enum CodingKeys: String, CodingKey { case config = "Config" }
    }
    let id: String
    let name: String
    let driver: String?
    let scope: String?
    let created: String?
    let isInternal: Bool?
    let enableIPv6: Bool?
    let ipam: IPAM?
    let containers: [String: Attached]?
    enum CodingKeys: String, CodingKey {
        case id = "Id", name = "Name", driver = "Driver", scope = "Scope", created = "Created"
        case isInternal = "Internal", enableIPv6 = "EnableIPv6", ipam = "IPAM", containers = "Containers"
    }
}
