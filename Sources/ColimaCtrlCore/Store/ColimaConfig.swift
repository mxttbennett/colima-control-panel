import Foundation

public struct ColimaResources: Equatable, Sendable {
    public var cpus: Int
    public var memory: Int
    public var disk: Int

    public init(cpus: Int, memory: Int, disk: Int) {
        self.cpus = cpus
        self.memory = memory
        self.disk = disk
    }
}

public struct HostSpecs: Equatable, Sendable {
    public let cores: Int
    public let memoryGiB: Int

    public init(cores: Int, memoryGiB: Int) {
        self.cores = cores
        self.memoryGiB = memoryGiB
    }

    public static var current: HostSpecs {
        HostSpecs(cores: ProcessInfo.processInfo.activeProcessorCount, memoryGiB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    public var maxCPUs: Int { max(1, cores) }
    /// Leaves 4 GiB for macOS itself.
    public var maxMemory: Int { max(2, memoryGiB - 4) }

    /// Half the cores (2 to 8) and a quarter of the memory (2 to 16 GiB) is plenty for most container work.
    public var recommended: ColimaResources {
        ColimaResources(cpus: min(8, max(2, cores / 2)), memory: min(16, max(2, memoryGiB / 4)), disk: 100)
    }
}

/// Reads and edits the three resource keys in Colima's own `colima.yaml`, leaving everything else untouched.
public enum ColimaConfigFile {
    public static func url(profile: String) -> URL {
        let directory = profile == "default" ? "default" : profile
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".colima/\(directory)/colima.yaml")
    }

    public static func parse(_ yaml: String) -> ColimaResources? {
        func value(_ key: String) -> Int? {
            let pattern = try! Regex("(?m)^\(key):[ \\t]*([0-9]+(?:\\.[0-9]+)?)[ \\t]*$")
            guard let match = yaml.firstMatch(of: pattern), let text = match.output[1].substring else { return nil }
            return Double(text).map { Int($0.rounded()) }
        }
        guard let cpus = value("cpu"), let memory = value("memory"), let disk = value("disk") else { return nil }
        return ColimaResources(cpus: cpus, memory: memory, disk: disk)
    }

    public static func update(_ yaml: String, with resources: ColimaResources) -> String {
        var result = yaml
        for (key, value) in [("cpu", resources.cpus), ("memory", resources.memory), ("disk", resources.disk)] {
            let pattern = try! Regex("(?m)^\(key):.*$")
            if result.firstMatch(of: pattern) != nil {
                result.replace(pattern, with: "\(key): \(value)")
            } else {
                result = "\(key): \(value)\n" + result
            }
        }
        return result
    }
}
