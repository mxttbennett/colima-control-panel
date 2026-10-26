import Foundation
import Observation

/// One graph's worth of samples. Rows observe only their own series, so a stats tick redraws only what changed.
@MainActor @Observable
public final class Series {
    public static let capacity = 100

    public private(set) var cpu: [Double] = []
    public private(set) var memory: [Double] = []
    public private(set) var memoryLimit: Double = 0

    public var latestCPU: Double { cpu.last ?? 0 }
    public var latestMemory: Double { memory.last ?? 0 }

    nonisolated init() {}

    func append(cpu: Double, memory: Double, memoryLimit: Double) {
        self.cpu.append(cpu)
        self.memory.append(memory)
        if self.cpu.count > Series.capacity {
            self.cpu.removeFirst(self.cpu.count - Series.capacity)
            self.memory.removeFirst(self.memory.count - Series.capacity)
        }
        self.memoryLimit = memoryLimit
    }
}

@MainActor
public final class StatsHistory {
    public let totals = Series()
    private var storage: [String: Series] = [:]

    public init() {}

    public func series(for id: String) -> Series {
        if let existing = storage[id] { return existing }
        let created = Series()
        storage[id] = created
        return created
    }

    func prune(keeping ids: Set<String>) {
        storage = storage.filter { ids.contains($0.key) }
    }

    func reset() {
        storage = [:]
    }
}
