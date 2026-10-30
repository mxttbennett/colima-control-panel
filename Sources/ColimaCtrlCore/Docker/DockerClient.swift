import Foundation

public struct DockerClient: Sendable {
    public let socketPath: String

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public static func defaultSocketPath(profile: String? = nil) -> String {
        let profile = profile ?? ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? UserDefaults.standard.string(forKey: "colimaProfile") ?? "default"
        return FileManager.default.homeDirectoryForCurrentUser.path + "/.colima/\(profile)/docker.sock"
    }

    public var socketExists: Bool { FileManager.default.fileExists(atPath: socketPath) }

    public func ping() async -> Bool {
        guard socketExists else { return false }
        return (try? await request("GET", "/_ping").status) == 200
    }

    public func request(_ method: String, _ path: String, body: Data? = nil) async throws -> (status: Int, body: Data) {
        let socketPath = socketPath
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try Self.perform(socketPath: socketPath, method: method, path: path, body: body) })
            }
        }
    }

    public func get<T: Decodable & Sendable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let (status, body) = try await request("GET", path)
        guard (200..<300).contains(status) else { throw DockerError.http(status: status, message: Self.message(from: body)) }
        do { return try JSONDecoder().decode(T.self, from: body) } catch { throw DockerError.decode("\(error)") }
    }

    /// Sends a write and throws Docker's own message on failure. 304 counts as success.
    public func send(_ method: String, _ path: String) async throws {
        let (status, body) = try await request(method, path)
        guard (200..<300).contains(status) || status == 304 else {
            throw DockerError.http(status: status, message: Self.message(from: body))
        }
    }

    /// Streams the decoded response body; cancelling the consumer closes the socket.
    public func stream(_ method: String = "GET", _ path: String) -> AsyncThrowingStream<Data, Error> {
        let socketPath = socketPath
        return AsyncThrowingStream { continuation in
            let box = SocketBox()
            continuation.onTermination = { _ in box.interrupt() }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.run(socketPath: socketPath, method: method, path: path, body: nil, receiveTimeout: nil, box: box) { head, chunk in
                        if let chunk, (200..<300).contains(head.status) { continuation.yield(chunk) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: box.wasInterrupted ? nil : error)
                }
            }
        }
    }

    static func message(from body: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let message = object["message"] as? String {
            return message
        }
        let text = String(decoding: body, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Docker returned an error" : text
    }

    private static func perform(socketPath: String, method: String, path: String, body: Data?) throws -> (status: Int, body: Data) {
        var status = 0
        var collected = Data()
        try run(socketPath: socketPath, method: method, path: path, body: body, receiveTimeout: 15, box: SocketBox()) { head, chunk in
            status = head.status
            if let chunk { collected.append(chunk) }
        }
        return (status, collected)
    }

    private static func run(
        socketPath: String, method: String, path: String, body: Data?, receiveTimeout: Int?, box: SocketBox,
        onChunk: (ResponseHead, Data?) -> Void
    ) throws {
        let socket = try UnixSocket(path: socketPath, receiveTimeout: receiveTimeout)
        defer { socket.close() }
        box.attach(socket)
        try socket.send(HTTPRequest.data(method: method, path: path, body: body))

        var parser = HeadParser()
        var head: ResponseHead?
        var chunks = ChunkDecoder()
        var received = 0

        func deliver(_ data: Data, _ head: ResponseHead) -> Bool {
            if head.isChunked {
                for piece in chunks.feed(data) { onChunk(head, piece) }
                return !chunks.isFinished
            }
            if !data.isEmpty { onChunk(head, data) }
            received += data.count
            if let length = head.contentLength { return received < length }
            return true
        }

        while true {
            let data = try socket.receive()
            if data.isEmpty { break }
            if let current = head {
                if !deliver(data, current) { break }
            } else if let parsed = parser.feed(data) {
                head = parsed.head
                onChunk(parsed.head, nil)
                if parsed.head.status == 204 || parsed.head.status == 304 || parsed.head.contentLength == 0 { break }
                if !parsed.remainder.isEmpty, !deliver(parsed.remainder, parsed.head) { break }
            }
        }
    }
}

final class SocketBox: @unchecked Sendable {
    private let lock = NSLock()
    private var socket: UnixSocket?
    private var interrupted = false

    var wasInterrupted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return interrupted
    }

    func attach(_ socket: UnixSocket) {
        lock.lock()
        defer { lock.unlock() }
        self.socket = socket
        if interrupted { socket.interrupt() }
    }

    func interrupt() {
        lock.lock()
        defer { lock.unlock() }
        interrupted = true
        socket?.interrupt()
    }
}
