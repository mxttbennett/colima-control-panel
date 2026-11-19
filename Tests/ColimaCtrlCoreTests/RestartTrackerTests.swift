import Foundation
import Testing
@testable import ColimaCtrlCore

private let start = Date(timeIntervalSince1970: 1_000_000)

@Test func threeDeathsInsideTheWindowRaiseOneAlert() {
    // Arrange
    var tracker = RestartTracker(threshold: 3, window: 300, cooldown: 900)

    // Act
    let results = [0.0, 30, 60, 90].map { tracker.recordDeath(of: "a", at: start.addingTimeInterval($0)) }

    // Assert
    #expect(results == [nil, nil, 3, nil])
}

@Test func slowDeathsNeverAddUp() {
    // Arrange
    var tracker = RestartTracker(threshold: 3, window: 300, cooldown: 900)

    // Act
    let results = [0.0, 200, 400, 600, 800].map { tracker.recordDeath(of: "a", at: start.addingTimeInterval($0)) }

    // Assert
    #expect(results.allSatisfy { $0 == nil })
}

@Test func aLoopCanAlertAgainAfterTheCooldown() {
    // Arrange
    var tracker = RestartTracker(threshold: 3, window: 300, cooldown: 900)
    for offset in [0.0, 10, 20] { _ = tracker.recordDeath(of: "a", at: start.addingTimeInterval(offset)) }

    // Act
    let later = [1000.0, 1010, 1020].map { tracker.recordDeath(of: "a", at: start.addingTimeInterval($0)) }

    // Assert
    #expect(later == [nil, nil, 3])
}

@Test func containersAreTrackedSeparately() {
    // Arrange
    var tracker = RestartTracker(threshold: 2, window: 300, cooldown: 900)

    // Act
    let a = tracker.recordDeath(of: "a", at: start)
    let b = tracker.recordDeath(of: "b", at: start.addingTimeInterval(1))
    let a2 = tracker.recordDeath(of: "a", at: start.addingTimeInterval(2))

    // Assert
    #expect(a == nil && b == nil && a2 == 2)
}

@Test func restartLoopAlertsDescribeTheCount() {
    // Arrange
    let alert = ContainerAlert(id: "x", name: "shop-web-1", kind: .restartLoop(count: 4))

    // Act & Assert
    #expect(alert.title == "shop-web-1 keeps restarting")
    #expect(alert.body == "It stopped 4 times in the last few minutes")
}
