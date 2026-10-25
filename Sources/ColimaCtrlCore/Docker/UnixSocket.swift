import Darwin
import Foundation

public enum DockerError: Error, LocalizedError, Sendable {
    case connect(String)
    case io(String)
    case http(status: Int, message: String)
    case decode(String)

    public var errorDescription: String? {
        switch self {
        case .connect(let reason): "Can't reach Docker: \(reason)"
        case .io(let reason): "Socket error: \(reason)"
        case .http(_, let message): message
        case .decode(let reason): "Unexpected Docker response: \(reason)"
        }
    }
}

final class UnixSocket: @unchecked Sendable {
    private let lock = NSLock()
    private var fd: Int32
    private var shutDown = false

    init(path: String, receiveTimeout: Int? = nil) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw DockerError.connect(String(cString: strerror(errno))) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(fd)
            throw DockerError.connect("socket path too long")
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            for (index, byte) in pathBytes.enumerated() { buffer[index] = UInt8(bitPattern: byte) }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let status = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, length) }
        }
        guard status == 0 else {
            let reason = String(cString: strerror(errno))
            Darwin.close(fd)
            throw DockerError.connect(reason)
        }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        if let receiveTimeout {
            var timeout = timeval(tv_sec: receiveTimeout, tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        }
        self.fd = fd
    }

    func send(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw DockerError.io(String(cString: strerror(errno)))
                }
                offset += written
            }
        }
    }

    /// Returns an empty Data at end of stream.
    func receive(maxLength: Int = 65536) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: maxLength)
        while true {
            let count = read(fd, &buffer, maxLength)
            if count >= 0 { return Data(buffer[0..<count]) }
            if errno == EINTR { continue }
            if errno == EAGAIN { throw DockerError.io("timed out waiting for Docker") }
            throw DockerError.io(String(cString: strerror(errno)))
        }
    }

    /// Unblocks a reader on another thread. The reader closes the descriptor.
    func interrupt() {
        lock.lock()
        defer { lock.unlock() }
        if !shutDown {
            shutDown = true
            Darwin.shutdown(fd, SHUT_RDWR)
        }
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }
}
