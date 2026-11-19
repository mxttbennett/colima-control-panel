import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func aNewerReleaseIsAvailable() {
    // Act
    let outcome = UpdateCheck.outcome(installed: "0.1.0", latestTag: "v0.2.0")

    // Assert
    #expect(outcome == .available("0.2.0"))
}

@Test func theSameOrAnOlderReleaseIsUpToDate() {
    // Act & Assert
    #expect(UpdateCheck.outcome(installed: "0.2.0", latestTag: "v0.2.0") == .upToDate)
    #expect(UpdateCheck.outcome(installed: "1.0", latestTag: "v0.9.9") == .upToDate)
    #expect(UpdateCheck.outcome(installed: "0.10.0", latestTag: "v0.9.0") == .upToDate)
}

@Test func versionsCompareNumberByNumberNotAsText() {
    // Act & Assert
    #expect(UpdateCheck.outcome(installed: "0.9.0", latestTag: "v0.10.0") == .available("0.10.0"))
    #expect(UpdateCheck.outcome(installed: "1.2", latestTag: "v1.2.1") == .available("1.2.1"))
}

@Test func buildsThatAreNotReleasesAreDevelopmentBuilds() {
    // Act & Assert
    #expect(UpdateCheck.outcome(installed: "ea2d8dc", latestTag: "v0.2.0") == .development)
    #expect(UpdateCheck.outcome(installed: "dev", latestTag: "v0.2.0") == .development)
}

@Test func aBuildPastTheLatestTagIsADevelopmentBuild() {
    // Act & Assert
    #expect(UpdateCheck.outcome(installed: "0.2.0-5-gea2d8dc", latestTag: "v0.2.0") == .development)
    #expect(UpdateCheck.outcome(installed: "0.2.0-5-gea2d8dc", latestTag: "v0.3.0") == .available("0.3.0"))
}

@Test func aTagThatIsNotAVersionCannotBeCompared() {
    // Act
    let outcome = UpdateCheck.outcome(installed: "0.2.0", latestTag: "nightly")

    // Assert
    #expect(outcome == .unknown)
}

@Test func theLatestReleaseDecodesItsTagAndPage() throws {
    // Arrange
    let json = #"{"tag_name":"v0.2.0","html_url":"https://github.com/mxttbennett/colima-control-panel/releases/tag/v0.2.0","draft":false}"#

    // Act
    let release = try JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8))

    // Assert
    #expect(release.tag == "v0.2.0")
    #expect(release.url.absoluteString.hasSuffix("/releases/tag/v0.2.0"))
}
