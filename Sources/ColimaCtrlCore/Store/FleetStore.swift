import Foundation
import Observation

public enum StatsDemand: Hashable, Sendable { case window, popover }

@MainActor @Observable
public final class FleetStore {
    public enum Connection: Sendable { case connecting, up, down }

    public private(set) var connection = Connection.connecting
    public private(set) var containers: [ContainerRow] = []
    public private(set) var images: [ImageRow] = []
    public private(set) var volumes: [VolumeRow] = []
    public private(set) var networks: [NetworkRow] = []
    public private(set) var disk: DiskUsage?
    public private(set) var info: EngineInfo?
    public var lastError: String?

    public let stats = StatsHistory()
    public let vm: ColimaVM
    public let client: DockerClient

    public var runningCount: Int { containers.reduce(0) { $0 + ($1.isRunning ? 1 : 0) } }
    public var health: FleetHealth { FleetHealth(containers) }

    @ObservationIgnored var startedAt: [String: Date] = [:]
    @ObservationIgnored var inspectCache: [String: ContainerInspect] = [:]
    @ObservationIgnored var lastSamples: [String: StatsSample] = [:]
    @ObservationIgnored private var liveness: Task<Void, Never>?
    @ObservationIgnored private var session: Task<Void, Never>?
    @ObservationIgnored private var statsTask: Task<Void, Never>?
    @ObservationIgnored private var demand: Set<StatsDemand> = []
    @ObservationIgnored private var refreshPending = false
    @ObservationIgnored var heavyPending = false

    public init(client: DockerClient = DockerClient(socketPath: DockerClient.defaultSocketPath()), vm: ColimaVM = ColimaVM()) {
        self.client = client
        self.vm = vm
    }

    // MARK: Lifecycle

    public func start() {
        guard liveness == nil else { return }
        liveness = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let self else { return }
                if await self.client.ping() {
                    failures = 0
                    if self.connection != .up { self.connected() }
                } else {
                    failures += 1
                    if self.connection != .down, failures >= 2 || self.connection == .connecting { self.disconnected() }
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func connected() {
        connection = .up
        session?.cancel()
        session = Task { [weak self] in
            guard let self else { return }
            await self.refresh(heavy: true)
            await self.watchEvents()
        }
        updateStatsTask()
    }

    private func disconnected() {
        connection = .down
        session?.cancel()
        session = nil
        updateStatsTask()
        containers = []
        startedAt = [:]
        lastSamples = [:]
        inspectCache = [:]
        stats.reset()
    }

    public func setDemand(_ source: StatsDemand, _ active: Bool) {
        if active { demand.insert(source) } else { demand.remove(source) }
        updateStatsTask()
    }

    /// Stats cost the engine CPU, so they only run while a window or popover is showing.
    private func updateStatsTask() {
        let wanted = connection == .up && !demand.isEmpty
        if wanted, statsTask == nil {
            statsTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.sampleStats()
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        } else if !wanted {
            statsTask?.cancel()
            statsTask = nil
            lastSamples = [:]
        }
    }

    // MARK: Refresh

    func refresh(heavy: Bool) async {
        do {
            if heavy { try await refreshHeavy() }
            try await refreshContainers()
        } catch {
            if connection == .up, !Task.isCancelled { lastError = error.localizedDescription }
        }
    }

    private func refreshContainers() async throws {
        let api = try await client.get("/containers/json?all=1", as: [APIContainer].self)
        await loadStartTimes(for: api.filter { $0.state == "running" && startedAt[$0.id] == nil }.map(\.id))
        let rows = api.map { ContainerRow($0, startedAt: startedAt[$0.id]) }
        if rows != containers { containers = rows }
        let ids = Set(rows.map(\.id))
        stats.prune(keeping: ids)
        inspectCache = inspectCache.filter { ids.contains($0.key) }
    }

    private func refreshHeavy() async throws {
        async let infoRequest = client.get("/info", as: APIInfo.self)
        async let dfRequest = client.get("/system/df", as: APIDf.self)
        async let networkRequest = client.get("/networks", as: [APINetwork].self)
        let (apiInfo, df, apiNetworks) = try await (infoRequest, dfRequest, networkRequest)

        let newInfo = EngineInfo(cpus: apiInfo.cpus, memory: apiInfo.memory, version: apiInfo.version, name: apiInfo.name)
        if newInfo != info { info = newInfo }

        let newImages = df.allImages.map {
            ImageRow(id: $0.id, tags: $0.repoTags ?? [], size: $0.size, created: Date(timeIntervalSince1970: TimeInterval($0.created)), containers: max(0, $0.containers ?? 0))
        }
        if newImages != images { images = newImages }

        let newVolumes = df.allVolumes.map {
            VolumeRow(name: $0.name, size: max(0, $0.usageData?.size ?? 0), refs: max(0, $0.usageData?.refCount ?? 0), project: $0.labels?["com.docker.compose.project"])
        }
        if newVolumes != volumes { volumes = newVolumes }

        let newNetworks = apiNetworks.map {
            NetworkRow(id: $0.id, name: $0.name, driver: $0.driver, scope: $0.scope, isInternal: $0.isInternal ?? false, subnet: $0.ipam?.config?.first?.subnet)
        }.sorted { $0.name < $1.name }
        if newNetworks != networks { networks = newNetworks }

        let newDisk = DiskUsage(
            images: Self.bucket(df.allImages, size: \.size, reclaimable: { ($0.containers ?? 0) < 1 }),
            containers: Self.bucket(df.allContainers, size: { $0.sizeRw ?? 0 }, reclaimable: { $0.state != "running" }),
            volumes: Self.bucket(df.allVolumes, size: { max(0, $0.usageData?.size ?? 0) }, reclaimable: { ($0.usageData?.refCount ?? 0) < 1 }),
            buildCache: Self.bucket(df.allCache, size: \.size, reclaimable: { $0.inUse != true })
        )
        if newDisk != disk { disk = newDisk }
    }

    private static func bucket<T>(_ items: [T], size: (T) -> Int64, reclaimable: (T) -> Bool) -> DiskBucket {
        DiskBucket(count: items.count, size: items.reduce(0) { $0 + size($1) }, reclaimable: items.filter(reclaimable).reduce(0) { $0 + size($1) })
    }

    private func loadStartTimes(for ids: [String]) async {
        guard !ids.isEmpty else { return }
        let client = client
        let results = await withTaskGroup(of: (String, Date?).self) { group in
            for id in ids {
                group.addTask {
                    let inspect = try? await client.get("/containers/\(id)/json", as: APIInspect.self)
                    return (id, inspect.flatMap { DockerDate.parse($0.state.startedAt) })
                }
            }
            var found: [(String, Date?)] = []
            for await result in group { found.append(result) }
            return found
        }
        for (id, date) in results { if let date { startedAt[id] = date } }
    }

    // MARK: Events

    private func watchEvents() async {
        let filters = #"{"type":["container","image","volume","network"]}"#.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let client = client
        while !Task.isCancelled {
            do {
                var splitter = LineSplitter()
                for try await chunk in client.stream("GET", "/events?filters=\(filters)") {
                    for line in splitter.feed(chunk) {
                        guard let event = try? JSONDecoder().decode(APIEvent.self, from: Data(line.utf8)) else { continue }
                        handle(event)
                    }
                }
            } catch {
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func handle(_ event: APIEvent) {
        let action = event.action.split(separator: ":").first.map(String.init) ?? event.action
        if event.type == "container", ["start", "restart", "die", "stop", "kill", "oom", "pause", "unpause"].contains(action), let id = event.actor?.id {
            startedAt[id] = nil
        }
        if event.type != "container" || action == "create" || action == "destroy" { heavyPending = true }
        scheduleRefresh()
    }

    /// Events arrive in bursts (a compose up emits dozens); one refresh per burst.
    func scheduleRefresh(after delay: Duration = .milliseconds(250)) {
        guard !refreshPending else { return }
        refreshPending = true
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            self.refreshPending = false
            let heavy = self.heavyPending
            self.heavyPending = false
            await self.refresh(heavy: heavy)
        }
    }

    // MARK: Stats

    private func sampleStats() async {
        let running = containers.filter { $0.state == "running" }.map(\.id)
        guard !running.isEmpty else {
            stats.totals.append(cpu: 0, memory: 0, memoryLimit: Double(info?.memory ?? 0))
            return
        }
        let client = client
        let seeded = Set(lastSamples.keys)
        let results = await withTaskGroup(of: (String, StatsSample, Double?)?.self) { group in
            for id in running {
                let previous = lastSamples[id]
                group.addTask {
                    // The first sample per container asks the engine to compute CPU over one second; later ones are instant and diffed here.
                    let path = "/containers/\(id)/stats?stream=false" + (seeded.contains(id) ? "&one-shot=true" : "")
                    guard let api = try? await client.get(path, as: APIStats.self) else { return nil }
                    let sample = StatsSample(api)
                    let baseline = previous ?? StatsSample(previousOf: api)
                    return (id, sample, baseline.map { sample.cpuPercent(since: $0) })
                }
            }
            var collected: [(String, StatsSample, Double?)] = []
            for await result in group { if let result { collected.append(result) } }
            return collected
        }
        guard !Task.isCancelled else { return }

        var totalCPU = 0.0
        var totalMemory = 0.0
        for (id, sample, cpu) in results {
            lastSamples[id] = sample
            let value = cpu ?? 0
            stats.series(for: id).append(cpu: value, memory: Double(sample.memory), memoryLimit: Double(sample.memoryLimit))
            totalCPU += value
            totalMemory += Double(sample.memory)
        }
        stats.totals.append(cpu: totalCPU, memory: totalMemory, memoryLimit: Double(info?.memory ?? 0))
    }
}
