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
    @ObservationIgnored private var automaticStart: Task<Void, Never>?
    @ObservationIgnored private var terminationRequested = false
    @ObservationIgnored private var terminationTask: Task<Bool, Never>?

    public convenience init(profile: String? = nil) {
        self.init(profile: profile, binary: Self.locateColima())
    }

    init(profile: String?, binary: String?) {
        self.profile = profile ?? ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? UserDefaults.standard.string(forKey: "colimaProfile") ?? "default"
        self.binary = binary
    }

    nonisolated static func arguments(for operation: Operation, profile: String, extra: [String] = []) -> [String] {
        [operation.rawValue] + (profile == "default" ? [] : ["--profile", profile]) + extra
    }

    nonisolated static func statusArguments(profile: String) -> [String] {
        ["status"] + (profile == "default" ? [] : ["--profile", profile])
    }

    nonisolated static func locateColima() -> String? {
        let fixed = ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
        let onPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/colima" }
        return (fixed + onPath).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Extra arguments (for example `--cpus 4`) only apply to `start`; `restart` re-reads the saved configuration.
    public func run(_ operation: Operation, extraArgs: [String] = []) {
        guard !terminationRequested, self.operation == nil, automaticStart == nil else { return }
        Task { _ = await perform(operation, extraArgs: extraArgs) }
    }

    public func startIfStopped() {
        guard !terminationRequested, automaticStart == nil, operation == nil else { return }
        guard let binary else {
            error = "Colima isn't installed. Run `brew install colima`."
            return
        }
        automaticStart = Task {
            let result = await ProcessRunner.captureResult(binary, Self.statusArguments(profile: profile))
            switch Self.runtimeStatus(result) {
            case .stopped:
                _ = await perform(.start, extraArgs: [])
            case .running:
                break
            case .failed(let message):
                error = message
            }
            automaticStart = nil
        }
    }

    public func stopIfRunning() async -> Bool {
        if let terminationTask { return await terminationTask.value }
        terminationRequested = true
        let task = Task { @MainActor in await stopForTermination() }
        terminationTask = task
        let stopped = await task.value
        terminationTask = nil
        terminationRequested = false
        return stopped
    }

    private func stopForTermination() async -> Bool {
        guard let binary else {
            error = "Colima isn't installed. Run `brew install colima`."
            return false
        }
        await automaticStart?.value
        while operation != nil { try? await Task.sleep(for: .milliseconds(100)) }
        let result = await ProcessRunner.captureResult(binary, Self.statusArguments(profile: profile))
        switch Self.runtimeStatus(result) {
        case .stopped:
            return true
        case .failed(let message):
            error = message
            return false
        case .running:
            return await perform(.stop, extraArgs: [], timeout: .seconds(60)) == 0
        }
    }

    private enum RuntimeStatus {
        case running
        case stopped
        case failed(String)
    }

    nonisolated private static func runtimeStatus(_ result: (status: Int32, output: String)) -> RuntimeStatus {
        if result.status == 0 { return .running }
        if result.output.localizedCaseInsensitiveContains("is not running") { return .stopped }
        let details = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(details.isEmpty ? "colima status exited with code \(result.status)" : "colima status failed: \(details)")
    }

    private func perform(_ operation: Operation, extraArgs: [String], timeout: Duration? = nil) async -> Int32 {
        self.operation = operation
        log = []
        error = nil
        defer { self.operation = nil }

        guard let binary else {
            error = "Colima isn't installed. Run `brew install colima`."
            return -1
        }
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let consumer = Task { @MainActor in
            for await line in lines {
                let clean = ProcessRunner.stripANSI(line).trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { log.append(clean) }
                if log.count > 200 { log.removeFirst(log.count - 200) }
            }
        }
        let status = await ProcessRunner.run(binary, Self.arguments(for: operation, profile: profile, extra: extraArgs), timeout: timeout) { continuation.yield($0) }
        continuation.finish()
        await consumer.value
        if status == -2 { error = "colima \(operation.rawValue) timed out after 60 seconds" }
        else if status != 0 { error = "colima \(operation.rawValue) exited with code \(status)" }
        return status
    }
}
