import Foundation
import Testing
@testable import ColimaCtrlCore

private func event(_ type: String, _ action: String, id: String = "abc123def4567890", time: Int = 1_700_000_000, _ attributes: [String: String] = [:]) -> APIEvent {
    let attrs = attributes.map { "\"\($0.key)\":\"\($0.value)\"" }.joined(separator: ",")
    let json = #"{"Type":"\#(type)","Action":"\#(action)","Actor":{"ID":"\#(id)","Attributes":{\#(attrs)}},"time":\#(time)}"#
    return try! JSONDecoder().decode(APIEvent.self, from: Data(json.utf8))
}

private func log(_ events: APIEvent...) -> ActivityLog {
    var log = ActivityLog()
    for event in events { log.record(event) }
    return log
}

@Test func containerStartNamesTheContainerAndItsImage() {
    // Arrange
    let start = event("container", "start", ["name": "web", "image": "nginx:1.27"])

    // Act
    let entry = log(start).events.first

    // Assert
    #expect(entry?.subject == "web")
    #expect(entry?.summary == "started")
    #expect(entry?.detail == "nginx:1.27")
    #expect(entry?.kind == .container)
    #expect(entry?.date == Date(timeIntervalSince1970: 1_700_000_000))
}

@Test func failedExitsAndUnhealthyChecksAreFailuresButQuietShutdownsAreNot() {
    // Arrange
    let crashed = event("container", "die", ["name": "api", "exitCode": "137"])
    let clean = event("container", "die", id: "other", ["name": "job", "exitCode": "0"])
    let unhealthy = event("container", "health_status: unhealthy", id: "third", ["name": "db"])
    let oom = event("container", "oom", id: "fourth", ["name": "big"])

    // Act
    let entries = log(crashed, clean, unhealthy, oom).events

    // Assert
    #expect(entries.map(\.summary) == ["ran out of memory", "unhealthy", "exited (0)", "exited (137)"])
    #expect(entries.map(\.isFailure) == [true, true, false, true])
}

@Test func chattyEventsAreLeftOut() {
    // Arrange
    let noise = [
        event("container", "exec_create: sh"), event("container", "exec_start: sh"), event("container", "exec_die"),
        event("container", "attach"), event("container", "resize"), event("container", "kill", ["signal": "15"]),
        event("volume", "mount"), event("volume", "unmount"), event("network", "connect"), event("network", "disconnect"),
    ]
    var log = ActivityLog()

    // Act
    for item in noise { log.record(item) }

    // Assert
    #expect(log.events.isEmpty)
}

@Test func aStopFoldsIntoTheQuietExitBeforeIt() {
    // Arrange
    let exit = event("container", "die", time: 100, ["name": "web", "exitCode": "0"])
    let stop = event("container", "stop", time: 101, ["name": "web"])

    // Act
    let entries = log(exit, stop).events

    // Assert
    #expect(entries.map(\.summary) == ["stopped"])
}

@Test func aStopKeepsTheFailedExitBeforeIt() {
    // Arrange
    let exit = event("container", "die", time: 100, ["name": "web", "exitCode": "1"])
    let stop = event("container", "stop", time: 101, ["name": "web"])

    // Act
    let entries = log(exit, stop).events

    // Assert
    #expect(entries.map(\.summary) == ["stopped", "exited (1)"])
}

@Test func aStopFoldsAKilledExitInEitherOrder() {
    // Arrange
    let stop = event("container", "stop", time: 100, ["name": "web"])
    let killed = event("container", "die", time: 100, ["name": "web", "exitCode": "137"])

    // Act
    let stopFirst = log(stop, killed).events
    let exitFirst = log(killed, stop).events

    // Assert
    #expect(stopFirst.map(\.summary) == ["stopped"])
    #expect(exitFirst.map(\.summary) == ["stopped"])
    #expect(stopFirst.map(\.isFailure) == [false])
    #expect(exitFirst.map(\.isFailure) == [false])
}

@Test func aFailedExitAfterAStopStaysVisible() {
    // Arrange
    let stop = event("container", "stop", time: 100, ["name": "web"])
    let crashed = event("container", "die", time: 100, ["name": "web", "exitCode": "2"])

    // Act
    let entries = log(stop, crashed).events

    // Assert
    #expect(entries.map(\.summary) == ["exited (2)", "stopped"])
}

@Test func aStopWithNoRecentExitStandsOnItsOwn() {
    // Arrange
    let exit = event("container", "die", time: 100, ["name": "web", "exitCode": "0"])
    let stop = event("container", "stop", time: 200, ["name": "web"])

    // Act
    let entries = log(exit, stop).events

    // Assert
    #expect(entries.map(\.summary) == ["stopped", "exited (0)"])
}

@Test func imagesAndNetworksFallBackToTheirNameOrAShortID() {
    // Arrange
    let image = event("image", "delete", id: "sha256:0123456789abcdef0123", ["name": "redis:7"])
    let unnamed = event("image", "delete", id: "sha256:fedcba9876543210ffff")
    let network = event("network", "create", ["name": "app_default"])

    // Act
    let entries = log(image, unnamed, network).events

    // Assert
    #expect(entries.map(\.subject) == ["app_default", "fedcba987654", "redis:7"])
    #expect(entries.map(\.summary) == ["created", "deleted", "deleted"])
}

@Test func theLogKeepsTheNewestEntriesFirstAndCapsItsSize() {
    // Arrange
    var log = ActivityLog()

    // Act
    for index in 0..<(ActivityLog.capacity + 20) { log.record(event("container", "start", id: "id\(index)", ["name": "c\(index)"])) }

    // Assert
    #expect(log.events.count == ActivityLog.capacity)
    #expect(log.events.first?.subject == "c\(ActivityLog.capacity + 19)")
    #expect(log.events.last?.subject == "c20")
}

@Test func clearingEmptiesTheLog() {
    // Arrange
    var log = log(event("container", "start", ["name": "web"]))

    // Act
    log.clear()

    // Assert
    #expect(log.events.isEmpty)
}

@Test func failuresAreCountedAfterTheLastEventYouSaw() {
    // Arrange
    var log = log(
        event("container", "die", id: "a", ["name": "one", "exitCode": "1"]),
        event("container", "start", id: "b", ["name": "two"]),
    )
    let seen = log.events.first?.id ?? -1

    // Act
    log.record(event("container", "oom", id: "c", ["name": "three"]))
    log.record(event("container", "die", id: "d", ["name": "four", "exitCode": "0"]))

    // Assert
    #expect(log.failureCount() == 2)
    #expect(log.failureCount(after: seen) == 1)
}
