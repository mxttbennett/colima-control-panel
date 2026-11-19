import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func bumpingMovesACommandToTheFrontAndCapsTheList() {
    // Arrange
    let recent = ["a", "b", "c"]

    // Act
    let bumped = RecentCommands.bump(recent, "c")
    let capped = RecentCommands.bump(["a", "b", "c"], "d", limit: 3)

    // Assert
    #expect(bumped == ["c", "a", "b"])
    #expect(capped == ["d", "a", "b"])
}

@Test func recentCommandsComeFirstInRecencyOrderAndTheRestKeepTheirOrder() {
    // Arrange
    let commands = ["go", "restart", "stop", "open", "logs"]

    // Act
    let ordered = RecentCommands.order(commands, recent: ["logs", "go", "missing"]) { $0 }

    // Assert
    #expect(ordered == ["logs", "go", "restart", "stop", "open"])
    #expect(RecentCommands.order(commands, recent: []) { $0 } == commands)
}
