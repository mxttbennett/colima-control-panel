import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func referencesSplitIntoNameAndTag() {
    #expect(ImageReference("nginx").query == "fromImage=nginx&tag=latest")
    #expect(ImageReference("nginx:alpine").query == "fromImage=nginx&tag=alpine")
    #expect(ImageReference("localhost:5000/team/app").query == "fromImage=localhost%3A5000/team/app&tag=latest")
    #expect(ImageReference("localhost:5000/team/app:2").query == "fromImage=localhost%3A5000/team/app&tag=2")
    #expect(ImageReference("redis@sha256:abc").query == "fromImage=redis%40sha256%3Aabc")
    #expect(ImageReference("  nginx  ").query == "fromImage=nginx&tag=latest")
}

@Test func blankReferencesAreInvalid() {
    #expect(!ImageReference("   ").isValid)
    #expect(ImageReference("nginx").isValid)
}

@Test func progressTracksTheLatestStatusAndOverallFraction() {
    // Arrange
    var progress = PullProgress()

    // Act
    progress.feed(#"{"status":"Pulling from library/nginx","id":"latest"}"#)
    progress.feed(#"{"status":"Downloading","progressDetail":{"current":50,"total":100},"id":"a"}"#)
    progress.feed(#"{"status":"Downloading","progressDetail":{"current":100,"total":300},"id":"b"}"#)

    // Assert
    #expect(progress.status == "Downloading")
    #expect(progress.fraction == 150.0 / 400.0)
    #expect(progress.error == nil)
}

@Test func progressRecordsErrorsAndIgnoresGarbage() {
    // Arrange
    var progress = PullProgress()

    // Act
    progress.feed("not json")
    progress.feed(#"{"error":"pull access denied","errorDetail":{"message":"pull access denied"}}"#)

    // Assert
    #expect(progress.error == "pull access denied")
    #expect(progress.fraction == nil)
}

private let pullClient = DockerClient(socketPath: DockerClient.defaultSocketPath())

@MainActor @Test(.enabled(if: pullClient.socketExists)) func pullingFromAnUnreachableRegistryThrowsTheEngineMessage() async {
    // Arrange
    let store = FleetStore(client: pullClient)

    // Act
    var thrown: Error?
    do { try await store.pull(image: ImageReference("localhost:1/ccp/none:1")) { _ in } } catch { thrown = error }

    // Assert
    let message = thrown?.localizedDescription ?? ""
    #expect(thrown != nil)
    #expect(message.isEmpty == false)
}
