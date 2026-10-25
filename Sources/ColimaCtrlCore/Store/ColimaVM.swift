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

    nonisolated static func arguments(for operation: Operation, profile: String) -> [String] {
        [operation.rawValue] + (profile == "default" ? [] : ["--profile", profile])
    }

    nonisolated static func locateColima() -> String? {
        let fixed = ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
        let onPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/colima" }
        return (fixed + onPath).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func run(_ operation: Operation) {
        guard self.operation == nil else { return }
        Task { await perform(operation) }
    }

    private func perform(_ operation: Operation) async {
        self.operation = operation
        log = []
        error = nil
        defer { self.operation = nil }

        guard let binary else {
            error = "Colima isn't installed. Run `brew install colima`."
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Self.arguments(for: operation, profile: profile)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let lines = AsyncStream<String> { continuation in
            let splitter = LockedSplitter()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.finish()
                } else {
                    for line in splitter.feed(data) { continuation.yield(line) }
                }
            }
        }

        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch {
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        for await line in lines {
            let clean = Self.stripANSI(line).trimmingCharacters(in: .whitespaces)
            if !clean.isEmpty { log.append(clean) }
            if log.count > 200 { log.removeFirst(log.count - 200) }
        }
        if status != 0 { error = "colima \(operation.rawValue) exited with code \(status)" }
    }

    nonisolated static func stripANSI(_ text: String) -> String {
        text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }
}

private final class LockedSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private var splitter = LineSplitter()

    func feed(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return splitter.feed(data)
    }
}
