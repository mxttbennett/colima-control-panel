import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func batchDeleteReportsHowManyRequestsFailed() async {
    // Arrange
    let client = DockerClient(socketPath: "/nonexistent-ccp.sock")

    // Act
    var thrown: Error?
    do { try await FleetStore.deleteAll(["/volumes/a", "/volumes/b"], client: client) } catch { thrown = error }
    let message = thrown?.localizedDescription ?? ""

    // Assert
    #expect(message.hasPrefix("2 of 2 failed"))
}

@Test func batchDeleteOfNothingSucceeds() async throws {
    try await FleetStore.deleteAll([], client: DockerClient(socketPath: "/nonexistent-ccp.sock"))
}

@Test func removalPathsEncodeVolumeNames() {
    #expect(FleetStore.volumePath("my vol") == "/volumes/my%20vol")
    #expect(FleetStore.volumePath("plain") == "/volumes/plain")
}
