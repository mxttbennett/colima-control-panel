import Foundation
import Testing
@testable import ColimaCtrlCore

private let now = Date(timeIntervalSince1970: 1_700_000_000)

@Test func theDefaultRangeLoadsTheLastThreeHundredLines() {
    // Act
    let query = LogRange.recent.query(now: now, capacity: 5000)

    // Assert
    #expect(query == "tail=300")
}

@Test func timeRangesAskForLinesSinceThenCapAtTheBufferSize() {
    // Act & Assert
    #expect(LogRange.fiveMinutes.query(now: now, capacity: 5000) == "since=1699999700&tail=5000")
    #expect(LogRange.hour.query(now: now, capacity: 2000) == "since=1699996400&tail=2000")
    #expect(LogRange.day.query(now: now, capacity: 5000) == "since=1699913600&tail=5000")
}

@Test func everythingIsLimitedToTheBufferSize() {
    // Act
    let query = LogRange.all.query(now: now, capacity: 10000)

    // Assert
    #expect(query == "tail=10000")
}
