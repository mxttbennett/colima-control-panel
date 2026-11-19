import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func detectsLevelsInCommonLogFormats() {
    // Arrange
    let cases: [(String, LogLevel?)] = [
        ("[18:25:45 INF] HTTP GET /", .info),
        ("[18:25:45 ERR] boom", .error),
        ("level=warn msg=slow", .warning),
        ("{\"level\":\"error\",\"msg\":\"x\"}", .error),
        ("2026-01-01 DEBUG cache miss", .debug),
        ("an error occurred in plain prose", nil),
        ("info: Program[0]", .info),
        ("warn: Microsoft.EntityFrameworkCore[10]", .warning),
        ("fail: App.Worker[0]", .error),
        ("information: not a level", nil),
    ]

    // Act & Assert
    for (text, expected) in cases { #expect(LogText.level(in: text) == expected, "\(text)") }
}

@Test func levelRangeCoversTheToken() throws {
    // Arrange
    let text = "[18:25:45 WRN] disk low"

    // Act
    let found = try #require(LogText.levelMatch(in: text))

    // Assert
    #expect(text[found.range] == "WRN")
    #expect(found.level == .warning)
}

@Test func findsLinksAndIgnoresPlainText() {
    // Arrange
    let text = "click http://localhost:8389/account/reset-password?code=abc to continue"

    // Act
    let links = LogText.links(in: text)

    // Assert
    #expect(links.count == 1)
    #expect(links.first?.url.absoluteString == "http://localhost:8389/account/reset-password?code=abc")
    #expect(LogText.links(in: "no links here").isEmpty)
}

@Test func filterMatchesAreCaseInsensitiveAndAllReturned() {
    // Arrange
    let text = "Error: error again"

    // Act
    let matches = LogText.matches(of: "ERROR", in: text)

    // Assert
    #expect(matches.map { String(text[$0]) } == ["Error", "error"])
    #expect(LogText.matches(of: "", in: text).isEmpty)
}
