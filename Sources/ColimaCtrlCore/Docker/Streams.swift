import Foundation

public struct LogFrame: Sendable, Equatable {
    public enum Stream: Sendable { case out, err }
    public let stream: Stream
    public let data: Data
}

/// Splits Docker's multiplexed log stream (8-byte header per frame) into frames.
public struct LogDemuxer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func feed(_ chunk: Data) -> [LogFrame] {
        buffer.append(chunk)
        var frames: [LogFrame] = []
        while buffer.count >= 8 {
            let base = buffer.startIndex
            let size = (Int(buffer[base + 4]) << 24) | (Int(buffer[base + 5]) << 16) | (Int(buffer[base + 6]) << 8) | Int(buffer[base + 7])
            guard buffer.count >= 8 + size else { break }
            let payload = Data(buffer[(base + 8)..<(base + 8 + size)])
            frames.append(LogFrame(stream: buffer[base] == 2 ? .err : .out, data: payload))
            buffer = Data(buffer[(base + 8 + size)...])
        }
        return frames
    }
}

public struct LineSplitter: Sendable {
    private var tail = Data()

    public init() {}

    public mutating func feed(_ data: Data) -> [String] {
        tail.append(data)
        var lines: [String] = []
        while let newline = tail.firstIndex(of: 0x0A) {
            var line = tail[tail.startIndex..<newline]
            if line.last == 0x0D { line = line.dropLast() }
            lines.append(String(decoding: line, as: UTF8.self))
            tail = Data(tail[(newline + 1)...])
        }
        return lines
    }
}
