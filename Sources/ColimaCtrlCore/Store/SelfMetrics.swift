import Darwin
import Foundation
import Observation

/// CPU and memory of this app, shown so the dashboard's own cost is visible.
@MainActor @Observable
public final class SelfMetrics {
    public private(set) var cpu: Double = 0
    public private(set) var memory: UInt64 = 0
    public let series = Series()

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastCPUSeconds: Double?
    @ObservationIgnored private var lastWall: Date?

    public init() {}

    /// Sampling runs only while something is on screen.
    public func setActive(_ active: Bool) {
        if active, task == nil {
            sample()
            task = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    self?.sample()
                }
            }
        } else if !active {
            task?.cancel()
            task = nil
            lastCPUSeconds = nil
            lastWall = nil
        }
    }

    func sample() {
        let now = Date()
        let seconds = Self.cpuSeconds()
        if let lastCPUSeconds, let lastWall {
            let elapsed = now.timeIntervalSince(lastWall)
            if elapsed > 0 { cpu = max(0, (seconds - lastCPUSeconds) / elapsed * 100) }
        }
        lastCPUSeconds = seconds
        lastWall = now
        memory = Self.footprint()
        series.append(cpu: cpu, memory: Double(memory), memoryLimit: 0)
    }

    nonisolated static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    /// The same number Activity Monitor calls "Memory": private plus compressed pages, without shared frameworks.
    nonisolated static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
