import Foundation

struct ResponseHead: Sendable {
    let status: Int
    let headers: [String: String]

    var isChunked: Bool { headers["transfer-encoding"]?.lowercased().contains("chunked") == true }
    var contentLength: Int? { headers["content-length"].flatMap { Int($0) } }
}

enum HTTPRequest {
    static func data(method: String, path: String, body: Data? = nil) -> Data {
        var head = "\(method) \(path) HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n"
        if let body { head += "Content-Length: \(body.count)\r\nContent-Type: application/json\r\n" } else if method != "GET" {
            head += "Content-Length: 0\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        if let body { data.append(body) }
        return data
    }
}

struct HeadParser {
    private var buffer = Data()
    private static let separator = Data("\r\n\r\n".utf8)

    /// Returns the parsed head and any body bytes that arrived with it, once the head is complete.
    mutating func feed(_ chunk: Data) -> (head: ResponseHead, remainder: Data)? {
        buffer.append(chunk)
        guard let range = buffer.range(of: Self.separator) else { return nil }
        let headText = String(decoding: buffer[buffer.startIndex..<range.lowerBound], as: UTF8.self)
        let remainder = Data(buffer[range.upperBound...])
        var lines = headText.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        let statusLine = lines.removeFirst()
        let status = statusLine.split(separator: " ").dropFirst().first.flatMap { Int($0) } ?? 0
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].lowercased()
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return (ResponseHead(status: status, headers: headers), remainder)
    }
}

struct ChunkDecoder {
    private enum State {
        case size
        case data(remaining: Int)
        case dataEnd
        case finished
    }

    private var buffer = Data()
    private var state = State.size
    private static let crlf = Data("\r\n".utf8)

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    mutating func feed(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var output: [Data] = []
        while true {
            switch state {
            case .size:
                guard let range = buffer.range(of: Self.crlf) else { return output }
                let line = String(decoding: buffer[buffer.startIndex..<range.lowerBound], as: UTF8.self)
                buffer = Data(buffer[range.upperBound...])
                let hex = line.split(separator: ";").first.map(String.init) ?? line
                let size = Int(hex.trimmingCharacters(in: .whitespaces), radix: 16) ?? 0
                state = size == 0 ? .finished : .data(remaining: size)
            case .data(let remaining):
                guard !buffer.isEmpty else { return output }
                let take = min(remaining, buffer.count)
                output.append(Data(buffer.prefix(take)))
                buffer = Data(buffer.dropFirst(take))
                state = take == remaining ? .dataEnd : .data(remaining: remaining - take)
            case .dataEnd:
                guard buffer.count >= 2 else { return output }
                buffer = Data(buffer.dropFirst(2))
                state = .size
            case .finished:
                return output
            }
        }
    }
}
