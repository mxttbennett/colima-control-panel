import Testing
@testable import ColimaCtrlCore

@Test func launchesCCPOnlyWhenColimaStarts() {
    // Arrange
    var observer = ColimaLaunchObserver()

    // Act
    let startsWhileStopped = observer.shouldLaunchCCP(isRunning: false)
    let startsAfterColimaStarts = observer.shouldLaunchCCP(isRunning: true)
    let ignoresRepeatedRunningState = observer.shouldLaunchCCP(isRunning: true)
    let ignoresStop = observer.shouldLaunchCCP(isRunning: false)
    let startsAfterNextColimaStart = observer.shouldLaunchCCP(isRunning: true)

    // Assert
    #expect(!startsWhileStopped)
    #expect(startsAfterColimaStarts)
    #expect(!ignoresRepeatedRunningState)
    #expect(!ignoresStop)
    #expect(startsAfterNextColimaStart)
}

@Test func statusArgumentsIncludeNonDefaultProfile() {
    // Arrange
    let defaultProfile = "default"
    let workProfile = "work"

    // Act
    let defaultArguments = ColimaVM.statusArguments(profile: defaultProfile)
    let workArguments = ColimaVM.statusArguments(profile: workProfile)

    // Assert
    #expect(defaultArguments == ["status"])
    #expect(workArguments == ["status", "--profile", "work"])
}
