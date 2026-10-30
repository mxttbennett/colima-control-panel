import Foundation
import Darwin

enum ProcessRunner {
    /// Runs a command and streams its combined output line by line. Returns the exit status, or -1 if it could not start.
    static func run(_ executable: String, _ arguments: [String], timeout: Duration? = nil, onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
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

        let didTimeOut = LockedFlag()
        let timeoutWork = timeout.map { _ in
            DispatchWorkItem {
                guard process.isRunning else { return }
                didTimeOut.set()
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
                }
            }
        }
        if let timeoutWork, let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int(timeout.components.seconds)), execute: timeoutWork)
        }
        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch {
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        timeoutWork?.cancel()
        for await line in lines { onLine(line) }
        return didTimeOut.value ? -2 : status
    }

    static func stripANSI(_ text: String) -> String {
        text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    /// Output of a short command, or nil if it failed.
    static func capture(_ executable: String, _ arguments: [String]) async -> String? {
        let result = await captureResult(executable, arguments)
        return result.status == 0 ? result.output : nil
    }

    static func captureResult(_ executable: String, _ arguments: [String]) async -> (status: Int32, output: String) {
        let box = LineBox()
        let status = await run(executable, arguments) { box.append($0) }
        return (status, box.joined)
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    func set() {
        lock.lock()
        defer { lock.unlock() }
        flag = true
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }
}

final class LockedSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private var splitter = LineSplitter()

    func feed(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return splitter.feed(data)
    }
}

final class LineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        lines.append(line)
    }

    var joined: String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}
