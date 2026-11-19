import Foundation
import Testing
@testable import ColimaCtrlCore

private func row(_ id: String, project: String? = nil, service: String? = nil, state: String = "running") throws -> ContainerRow {
    let labels = [project.map { "\"com.docker.compose.project\":\"\($0)\"" }, service.map { "\"com.docker.compose.service\":\"\($0)\"" }].compactMap { $0 }.joined(separator: ",")
    let json = """
    {"Id":"\(id)","Names":["/\(id)"],"Image":"img","State":"\(state)","Status":"Up","Created":1,"Labels":{\(labels)}}
    """
    return ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: nil)
}

@Test func dockListsRunningContainersByNameAndCapsTheCount() throws {
    // Arrange
    let rows = try [row("b"), row("a"), row("c", state: "exited")] + (0..<12).map { try row("z\($0)") }

    // Act
    let listed = DockMenu.runningContainers(rows, limit: 3)

    // Act & Assert
    #expect(listed.map(\.id) == ["a", "b", "z0"])
}

@Test func dockProjectsReportRunningAndTotalCounts() throws {
    // Arrange
    let rows = try [row("a1", project: "beta"), row("a2", project: "beta", state: "exited"), row("b1", project: "alpha"), row("solo")]

    // Act
    let projects = DockMenu.projects(rows)

    // Assert
    #expect(projects.map(\.name) == ["alpha", "beta"])
    #expect(projects.map(\.running) == [1, 1])
    #expect(projects.map(\.total) == [1, 2])
}
