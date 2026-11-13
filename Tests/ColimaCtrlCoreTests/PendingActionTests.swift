import Foundation
import Testing
@testable import ColimaCtrlCore

private let deadClient = DockerClient(socketPath: "/nonexistent/colima.sock")

@MainActor private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(50)) }
}

@MainActor @Test func performMarksContainersPendingThenClearsThemAfterFailure() async throws {
    // Arrange
    let store = FleetStore(client: deadClient)

    // Act
    store.perform(.stop, on: ["a", "b"])

    // Assert
    #expect(store.pending["a"] == .stopping)
    #expect(store.pending["b"] == .stopping)
    try await waitUntil { store.pending.isEmpty }
    #expect(store.pending.isEmpty)
}

@MainActor @Test func failedActionReportsWhatFailed() async throws {
    // Arrange
    let store = FleetStore(client: deadClient)

    // Act
    store.perform(.restart, on: ["a", "b"])
    try await waitUntil { store.lastError != nil }

    // Assert
    #expect(store.lastError?.hasPrefix("Restart 2 containers: ") == true)
}

@MainActor @Test func removeAndPruneAreMarkedPending() {
    // Arrange
    let store = FleetStore(client: deadClient)

    // Act
    store.remove(containers: ["a"])
    store.prune(.volumes)

    // Assert
    #expect(store.pending["a"] == .removing)
    #expect(store.pending[PruneKind.volumes.pendingKey] == .pruning)
}
