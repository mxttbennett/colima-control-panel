import Foundation
import Testing
@testable import ColimaCtrlCore

private func row(_ id: String, project: String? = nil, service: String? = nil, directory: String? = nil, state: String = "running", image: String = "img", started: TimeInterval? = nil, hostPort: Int? = nil, name: String? = nil) throws -> ContainerRow {
    let labels = [
        project.map { "\"com.docker.compose.project\":\"\($0)\"" }, service.map { "\"com.docker.compose.service\":\"\($0)\"" },
        directory.map { "\"com.docker.compose.project.working_dir\":\"\($0)\"" },
    ].compactMap { $0 }.joined(separator: ",")
    let json = """
    {"Id":"\(id)","Names":["/\(name ?? id)"],"Image":"\(image)","State":"\(state)","Status":"Up","Created":1,"Labels":{\(labels)},"Ports":[\(hostPort.map { "{\"PrivatePort\":80,\"PublicPort\":\($0),\"Type\":\"tcp\"}" } ?? "")]}
    """
    return ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: started.map { Date(timeIntervalSince1970: $0) })
}

@Test func projectsSortByNameWithLooseContainersLast() throws {
    // Arrange
    let rows = [try row("solo"), try row("b1", project: "beta"), try row("a1", project: "alpha")]

    // Act
    let groups = ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: .name)

    // Assert
    #expect(groups.map(\.project) == ["alpha", "beta", nil])
}

@Test func filterMatchesNameServiceProjectAndImage() throws {
    // Arrange
    let rows = [
        try row("web-1", project: "shop", service: "web", image: "nginx"),
        try row("db-1", project: "shop", service: "db", image: "postgres"),
        try row("cache", image: "redis"),
    ]

    // Act & Assert
    #expect(ContainerGrouping.groups(rows: rows, query: "NGINX", runningOnly: false, sort: .name).flatMap(\.rows).map(\.id) == ["web-1"])
    #expect(ContainerGrouping.groups(rows: rows, query: "shop", runningOnly: false, sort: .name).flatMap(\.rows).count == 2)
    #expect(ContainerGrouping.groups(rows: rows, query: "cache", runningOnly: false, sort: .name).flatMap(\.rows).map(\.id) == ["cache"])
    #expect(ContainerGrouping.groups(rows: rows, query: "nothing", runningOnly: false, sort: .name).isEmpty)
}

@Test func runningOnlyDropsStoppedContainersAndCountsRunning() throws {
    // Arrange
    let rows = [try row("a", project: "p"), try row("b", project: "p", state: "exited")]

    // Act
    let all = ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: .name)
    let running = ContainerGrouping.groups(rows: rows, query: "", runningOnly: true, sort: .name)

    // Assert
    #expect(all.first?.rows.count == 2 && all.first?.runningCount == 1)
    #expect(running.first?.rows.map(\.id) == ["a"])
}

@Test func rowsSortByCPUThenMemoryThenUptime() throws {
    // Arrange
    let rows = [try row("a", started: 300), try row("b", started: 100), try row("c", state: "exited")]
    let cpu = ["a": 5.0, "b": 50.0, "c": 0.0]
    let memory = ["a": 900.0, "b": 100.0, "c": 0.0]

    // Act
    func order(_ sort: ContainerSort) -> [String] {
        ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: sort, cpu: { cpu[$0] ?? 0 }, memory: { memory[$0] ?? 0 }).flatMap(\.rows).map(\.id)
    }

    // Assert
    #expect(order(.name) == ["a", "b", "c"])
    #expect(order(.cpu) == ["b", "a", "c"])
    #expect(order(.memory) == ["a", "b", "c"])
    #expect(order(.uptime) == ["b", "a", "c"])
}

@Test func equalMetricsBreakTiesByName() throws {
    // Arrange
    let rows = [try row("z"), try row("m"), try row("a")]

    // Act
    let ids = ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: .cpu).flatMap(\.rows).map(\.id)

    // Assert
    #expect(ids == ["a", "m", "z"])
}

@Test func uptimeTextCrossesEachUnitBoundary() {
    // Arrange
    let start = Date(timeIntervalSince1970: 0)
    func text(_ seconds: Double) -> String { Uptime.text(since: start, now: Date(timeIntervalSince1970: seconds)) }

    // Act & Assert
    #expect(text(59) == "59s")
    #expect(text(61) == "1m 1s")
    #expect(text(3_660) == "1h 1m")
    #expect(text(90_000) == "1d 1h")
    #expect(text(-5) == "0s")
}

@Test func exitDescriptionsExplainSignalsAndOutOfMemory() {
    #expect(ContainerInspect.exitDescription(code: 0, oomKilled: false) == "0 (success)")
    #expect(ContainerInspect.exitDescription(code: 137, oomKilled: false) == "137 (signal 9)")
    #expect(ContainerInspect.exitDescription(code: 137, oomKilled: true) == "137 (out of memory)")
    #expect(ContainerInspect.exitDescription(code: 2, oomKilled: false) == "2")
}

@Test func projectDirectoryComesFromTheComposeLabel() throws {
    // Arrange
    let rows = [try row("a", project: "p"), try row("b", project: "p", directory: "/work/p")]

    // Act
    let groups = ContainerGrouping.groups(rows: rows, query: "", runningOnly: false, sort: .name)

    // Assert
    #expect(groups.first?.directory == "/work/p")
    #expect(ContainerGrouping.groups(rows: [try row("solo")], query: "", runningOnly: false, sort: .name).first?.directory == nil)
}

@Test func combinedSeriesAlignOnTheLatestSamples() {
    // Arrange
    let lists: [[Double]] = [[1, 2, 3], [10, 20], []]

    // Act
    let combined = SeriesMath.sumAligned(lists)

    // Assert
    #expect(combined == [1, 12, 23])
    #expect(SeriesMath.sumAligned([]) == [])
}

@Test func filterMatchesAPublishedPortOrAnIDPrefix() throws {
    // Arrange
    let web = try row("abcd1234ef", hostPort: 8080, name: "web")
    let db = try row("99887766aa", hostPort: 5432, name: "db")

    // Act & Assert
    #expect(ContainerGrouping.matches(web, query: "8080"))
    #expect(ContainerGrouping.matches(web, query: "80"))
    #expect(!ContainerGrouping.matches(db, query: "8080"))
    #expect(ContainerGrouping.matches(web, query: "abcd"))
    #expect(!ContainerGrouping.matches(web, query: "bcd1"))
    #expect(!ContainerGrouping.matches(web, query: "8"))
    #expect(!ContainerGrouping.matches(web, query: "abc"))
}
