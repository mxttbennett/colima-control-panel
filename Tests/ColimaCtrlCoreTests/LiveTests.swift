import Foundation
import Testing
@testable import ColimaCtrlCore

private let client = DockerClient(socketPath: DockerClient.defaultSocketPath())

@Test(.enabled(if: client.socketExists)) func liveEngineAnswersAndDecodes() async throws {
    #expect(await client.ping())
    let info = try await client.get("/info", as: APIInfo.self)
    #expect(info.cpus > 0)
    _ = try await client.get("/containers/json?all=1", as: [APIContainer].self)
    let df = try await client.get("/system/df", as: APIDf.self)
    _ = df.allImages
    _ = try await client.get("/networks", as: [APINetwork].self)
}

@Test(.enabled(if: client.socketExists)) func liveEventStreamStopsWhenCancelled() async throws {
    let task = Task { () -> Int in
        var count = 0
        for try await chunk in client.stream("GET", "/events") { count += chunk.count }
        return count
    }
    try await Task.sleep(for: .milliseconds(300))
    task.cancel()
    _ = try? await task.value
}
