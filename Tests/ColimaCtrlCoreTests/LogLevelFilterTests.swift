import Foundation
import Testing
@testable import ColimaCtrlCore

private func line(_ id: Int, _ text: String, error: Bool = false) -> LogLine {
    LogLine(id: id, timestamp: "", text: text, isError: error)
}

@Test func warningFilterKeepsWarningsErrorsAndTheirContinuationLines() {
    // Arrange
    let lines = [
        line(1, "[10:00:00 INF] started"),
        line(2, "[10:00:01 WRN] slow query"),
        line(3, "    SELECT * FROM big_table"),
        line(4, "[10:00:02 INF] done"),
        line(5, "[10:00:03 ERR] boom"),
    ]

    // Act
    let kept = LogLevelFilter.warnings.apply(lines).map(\.id)

    // Assert
    #expect(kept == [2, 3, 5])
}

@Test func errorFilterKeepsOnlyErrorsAndStderrLinesWithoutALevel() {
    // Arrange
    let lines = [
        line(1, "[10:00:00 WRN] careful"),
        line(2, "plain stderr text", error: true),
        line(3, "[10:00:02 INF] fine"),
        line(4, "{\"level\":\"error\",\"msg\":\"x\"}"),
    ]

    // Act & Assert
    #expect(LogLevelFilter.errors.apply(lines).map(\.id) == [2, 4])
    #expect(LogLevelFilter.all.apply(lines).count == 4)
}

@Test func linesBeforeAnyLevelAreHiddenByTheLevelFilters() {
    // Arrange
    let lines = [line(1, "banner without a level"), line(2, "[10:00:00 ERR] bad")]

    // Act & Assert
    #expect(LogLevelFilter.errors.apply(lines).map(\.id) == [2])
}
