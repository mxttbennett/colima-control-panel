import Foundation
import Testing
@testable import ColimaCtrlCore

private let liveClient = DockerClient(socketPath: DockerClient.defaultSocketPath())

@MainActor @Test(.enabled(if: liveClient.socketExists)) func storeReportsLoadedOnlyAfterTheFirstRefresh() async throws {
    let store = FleetStore(client: liveClient)
    #expect(!store.hasLoaded)
    store.start()
    for _ in 0..<50 where !store.hasLoaded { try await Task.sleep(for: .milliseconds(100)) }
    #expect(store.hasLoaded)
    #expect(store.info != nil)
}
