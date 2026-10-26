import Foundation

enum ProcessRunner {
    /// Runs a command and streams its combined output line by line. Returns the exit status, or -1 if it could not start.
    static func run(_ executable: String, _ arguments: [String], onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
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

        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch {
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        for await line in lines { onLine(line) }
        return status
    }

    static func stripANSI(_ text: String) -> String {
        text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
    }

    /// Output of a short command, or nil if it failed.
    static func capture(_ executable: String, _ arguments: [String]) async -> String? {
        let box = LineBox()
        let status = await run(executable, arguments) { box.append($0) }
        return status == 0 ? box.joined : nil
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
