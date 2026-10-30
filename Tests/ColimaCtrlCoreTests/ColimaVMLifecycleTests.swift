import Foundation
import Testing
@testable import ColimaCtrlCore

@Test @MainActor func startsColimaWhenStatusReportsStopped() async throws {
    // Arrange
    let fixture = try ColimaFixture()
    defer { fixture.cleanUp() }
    let vm = ColimaVM(profile: "work", binary: fixture.binary.path)

    // Act
    vm.startIfStopped()
    for _ in 0..<300 where !FileManager.default.fileExists(atPath: fixture.state.path) {
        try await Task.sleep(for: .milliseconds(10))
    }
    for _ in 0..<300 where vm.operation != nil { try await Task.sleep(for: .milliseconds(10)) }

    // Assert
    #expect(FileManager.default.fileExists(atPath: fixture.state.path))
    #expect(vm.operation == nil)
}

@Test @MainActor func stopsColimaWhenRunning() async throws {
    // Arrange
    let fixture = try ColimaFixture(running: true)
    defer { fixture.cleanUp() }
    let vm = ColimaVM(profile: "work", binary: fixture.binary.path)

    // Act
    let stopped = await vm.stopIfRunning()

    // Assert
    #expect(stopped == true)
    let stateExists = FileManager.default.fileExists(atPath: fixture.state.path)
    #expect(stateExists == false)
}

@Test @MainActor func ignoresNewOperationsWhileQuitIsCheckingStatus() async throws {
    // Arrange
    let fixture = try ColimaFixture(running: true, statusDelay: true)
    defer { fixture.cleanUp() }
    let vm = ColimaVM(profile: "work", binary: fixture.binary.path)

    // Act
    let stopping = Task { await vm.stopIfRunning() }
    try await Task.sleep(for: .milliseconds(100))
    vm.run(.start)
    let stopped = await stopping.value

    // Assert
    let commands = try String(contentsOf: fixture.calls, encoding: .utf8)
    #expect(stopped)
    #expect(!commands.contains("start"))
    #expect(commands.components(separatedBy: .newlines).filter { $0 == "stop" }.count == 1)
}

@Test @MainActor func concurrentQuitRequestsShareOneStop() async throws {
    // Arrange
    let fixture = try ColimaFixture(running: true, statusDelay: true)
    defer { fixture.cleanUp() }
    let vm = ColimaVM(profile: "work", binary: fixture.binary.path)

    // Act
    async let first = vm.stopIfRunning()
    async let second = vm.stopIfRunning()
    let results = await (first, second)

    // Assert
    let commands = try String(contentsOf: fixture.calls, encoding: .utf8)
    #expect(results.0)
    #expect(results.1)
    #expect(commands.components(separatedBy: .newlines).filter { $0 == "stop" }.count == 1)
}

@Test @MainActor func doesNotStartOrQuitWhenColimaStatusFailsUnexpectedly() async throws {
    // Arrange
    let fixture = try ColimaFixture(statusError: true)
    defer { fixture.cleanUp() }
    let vm = ColimaVM(profile: "work", binary: fixture.binary.path)

    // Act
    vm.startIfStopped()
    let stopped = await vm.stopIfRunning()

    // Assert
    #expect(!FileManager.default.fileExists(atPath: fixture.state.path))
    #expect(!stopped)
    #expect(vm.error?.contains("status failed") == true)
}

@Test func timedOutProcessReturnsTheTimeoutStatus() async throws {
    // Arrange
    let fixture = try ColimaFixture(hangingStop: true)
    defer { fixture.cleanUp() }

    // Act
    let status = await ProcessRunner.run(fixture.binary.path, ["stop"], timeout: .seconds(1)) { _ in }

    // Assert
    #expect(status == -2)
}

private struct ColimaFixture {
    let directory: URL
    let binary: URL
    let state: URL
    let calls: URL

    init(running: Bool = false, statusError: Bool = false, hangingStop: Bool = false, statusDelay: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        binary = directory.appendingPathComponent("colima")
        state = directory.appendingPathComponent("running")
        calls = directory.appendingPathComponent("calls")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let statusDelayCommand = statusDelay ? "sleep 0.5; " : ""
        let statusCommand = statusError
            ? "status) \(statusDelayCommand)echo 'unexpected status failure' >&2; exit 2 ;;"
            : "status) \(statusDelayCommand)if test -f \"\(state.path)\"; then exit 0; else echo 'FATA[0000] colima is not running' >&2; exit 1; fi ;;"
        let stopCommand = hangingStop ? "stop) sleep 20 ;;" : "stop) rm -f \"\(state.path)\" ;;"
        let script = """
        #!/bin/sh
        echo "$1" >> "\(calls.path)"
        case "$1" in
          \(statusCommand)
          start) touch "\(state.path)" ;;
          \(stopCommand)
          *) exit 2 ;;
        esac
        """
        try script.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        if running { _ = FileManager.default.createFile(atPath: state.path, contents: Data()) }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
