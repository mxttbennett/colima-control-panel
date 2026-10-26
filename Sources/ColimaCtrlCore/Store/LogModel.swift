import Foundation
import Observation

public struct LogLine: Identifiable, Sendable, Equatable {
    public let id: Int
    public let timestamp: String
    public let text: String
    public let isError: Bool
}

@MainActor @Observable
public final class LogModel {
    public static let capacity = 5000

    public private(set) var lines: [LogLine] = []
    public private(set) var failure: String?

    @ObservationIgnored private let client: DockerClient
    @ObservationIgnored private let containerID: String
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var pending: [(String, Bool)] = []
    @ObservationIgnored private var flushScheduled = false

    public init(client: DockerClient, containerID: String) {
        self.client = client
        self.containerID = containerID
    }

    public func start(tail: Int = 300) {
        guard task == nil else { return }
        task = Task.detached(priority: .userInitiated) { [client, containerID, weak self] in
            do {
                let tty = try await client.get("/containers/\(containerID)/json", as: APITtyProbe.self).config.tty ?? false
                let path = "/containers/\(containerID)/logs?follow=1&stdout=1&stderr=1&timestamps=1&tail=\(tail)"
                var demuxer = LogDemuxer()
                var splitters = [LogFrame.Stream.out: LineSplitter(), .err: LineSplitter()]
                for try await chunk in client.stream("GET", path) {
                    let frames = tty ? [LogFrame(stream: .out, data: chunk)] : demuxer.feed(chunk)
                    for frame in frames {
                        for line in splitters[frame.stream]!.feed(frame.data) { await self?.enqueue(line, isError: frame.stream == .err) }
                    }
                }
            } catch {
                if !Task.isCancelled { await self?.fail(error.localizedDescription) }
            }
        }
    }

    private func fail(_ message: String) {
        failure = message
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    /// Lines arrive in bursts; one flush per 80 ms keeps the view from re-rendering per line.
    private func enqueue(_ line: String, isError: Bool) {
        pending.append((line, isError))
        guard !flushScheduled else { return }
        flushScheduled = true
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            flush()
        }
    }

    private func flush() {
        flushScheduled = false
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        lines.append(contentsOf: batch.map { raw, isError in
            let parts = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            defer { nextID += 1 }
            return LogLine(id: nextID, timestamp: parts.count > 1 ? String(parts[0]) : "", text: parts.count > 1 ? String(parts[1]) : raw, isError: isError)
        })
        if lines.count > Self.capacity + 500 { lines.removeFirst(lines.count - Self.capacity) }
    }
}
