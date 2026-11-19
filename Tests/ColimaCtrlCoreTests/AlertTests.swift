import Foundation
import Testing
@testable import ColimaCtrlCore

private func row(id: String = "abc", state: String = "running", status: String = "Up 2 minutes (healthy)") throws -> ContainerRow {
    let json = """
    {"Id":"\(id)","Names":["/shop-web-1"],"Image":"web","State":"\(state)","Status":"\(status)","Created":1}
    """
    return ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: nil)
}

@Test func exitCodeComesFromTheStatusText() throws {
    #expect(try row(state: "exited", status: "Exited (137) 3 minutes ago").exitCode == 137)
    #expect(try row(state: "exited", status: "Exited (0) 1 hour ago").exitCode == 0)
    #expect(try row().exitCode == nil)
}

@Test func aRunningContainerThatExitsWithAnErrorRaisesAnAlert() throws {
    // Arrange
    let before = [try row()]
    let after = [try row(state: "exited", status: "Exited (1) 2 seconds ago")]

    // Act
    let alerts = ContainerAlert.diff(old: before, new: after, ignoring: [])

    // Assert
    #expect(alerts.map(\.kind) == [.exited(code: 1)])
    #expect(alerts.first?.title == "shop-web-1 exited")
    #expect(alerts.first?.body == "Exit code 1")
}

@Test func cleanAndSignalExitsDoNotRaiseAlerts() throws {
    // Arrange
    let before = [try row()]

    // Act & Assert
    for status in ["Exited (0) 1 second ago", "Exited (143) 1 second ago", "Exited (130) 1 second ago"] {
        #expect(ContainerAlert.diff(old: before, new: [try row(state: "exited", status: status)], ignoring: []).isEmpty)
    }
}

@Test func becomingUnhealthyRaisesOneAlert() throws {
    // Arrange
    let before = [try row()]
    let after = [try row(status: "Up 2 minutes (unhealthy)")]

    // Act
    let alerts = ContainerAlert.diff(old: before, new: after, ignoring: [])
    let repeated = ContainerAlert.diff(old: after, new: after, ignoring: [])

    // Assert
    #expect(alerts.map(\.kind) == [.unhealthy])
    #expect(repeated.isEmpty)
}

@Test func containersWithPendingActionsAreIgnored() throws {
    // Arrange
    let before = [try row()]
    let after = [try row(state: "exited", status: "Exited (1) 2 seconds ago")]

    // Act & Assert
    #expect(ContainerAlert.diff(old: before, new: after, ignoring: ["abc"]).isEmpty)
}
