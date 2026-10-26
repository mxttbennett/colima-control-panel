import Foundation
import Observation

@MainActor @Observable
public final class ColimaVM {
    public enum Operation: String, Sendable { case start, stop, restart }

    public private(set) var operation: Operation?
    public private(set) var log: [String] = []
    public private(set) var error: String?

    public var isBusy: Bool { operation != nil }

    @ObservationIgnored private let profile: String
    @ObservationIgnored private let binary: String?

    public init(profile: String = ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? "default") {
        self.profile = profile
        self.binary = Self.locateColima()
    }

    nonisolated static func arguments(for operation: Operation, profile: String, extra: [String] = []) -> [String] {
        [operation.rawValue] + (profile == "default" ? [] : ["--profile", profile]) + extra
    }

    nonisolated static func locateColima() -> String? {
        let fixed = ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
        let onPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/colima" }
        return (fixed + onPath).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Extra arguments (for example `--cpus 4`) only apply to `start`; `restart` re-reads the saved configuration.
    public func run(_ operation: Operation, extraArgs: [String] = []) {
        guard self.operation == nil else { return }
        Task { await perform(operation, extraArgs: extraArgs) }
    }

    private func perform(_ operation: Operation, extraArgs: [String]) async {
        self.operation = operation
        log = []
        error = nil
        defer { self.operation = nil }

        guard let binary else {
            error = "Colima isn't installed. Run `brew install colima`."
            return
        }
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let consumer = Task { @MainActor in
            for await line in lines {
                let clean = ProcessRunner.stripANSI(line).trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { log.append(clean) }
                if log.count > 200 { log.removeFirst(log.count - 200) }
            }
        }
        let status = await ProcessRunner.run(binary, Self.arguments(for: operation, profile: profile, extra: extraArgs)) { continuation.yield($0) }
        continuation.finish()
        await consumer.value
        if status != 0 { error = "colima \(operation.rawValue) exited with code \(status)" }
    }
}
