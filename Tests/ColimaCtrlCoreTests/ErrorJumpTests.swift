import Foundation
import Testing
@testable import ColimaCtrlCore

private func line(_ id: Int, _ text: String, error: Bool = false) -> LogLine {
    LogLine(id: id, timestamp: "", text: text, isError: error)
}

@Test func errorIDsListLinesWithAnErrorLevelOrBareStderr() {
    // Arrange
    let lines = [
        line(1, "[10:00:00 INF] started"),
        line(2, "[10:00:01 ERR] boom"),
        line(3, "plain stderr text", error: true),
        line(4, "[10:00:02 WRN] careful", error: true),
        line(5, "fail: App.Worker[0]"),
    ]

    // Act
    let ids = LogText.errorIDs(in: lines)

    // Assert
    #expect(ids == [2, 3, 5])
    #expect(LogText.errorIDs(in: []).isEmpty)
}

private func row(_ id: String, project: String, status: String) throws -> ContainerRow {
    let json = """
    {"Id":"\(id)","Names":["/\(id)"],"Image":"i","State":"running","Status":"\(status)","Created":1,
     "Labels":{"com.docker.compose.project":"\(project)"}}
    """
    return ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: nil)
}

@Test func projectGroupsCountUnhealthyContainers() throws {
    // Arrange
    let rows = [
        try row("a", project: "p", status: "Up 1 minute (healthy)"),
        try row("b", project: "p", status: "Up 1 minute (unhealthy)"),
        try row("c", project: "p", status: "Up 3 seconds (health: starting)"),
    ]

    // Act
    let groups = ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: .name)

    // Assert
    #expect(groups.first?.unhealthyCount == 1)
}
