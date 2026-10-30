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
    #expect(stopped)
    #expect(!FileManager.default.fileExists(atPath: fixture.state.path))
}

private struct ColimaFixture {
    let directory: URL
    let binary: URL
    let state: URL

    init(running: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        binary = directory.appendingPathComponent("colima")
        state = directory.appendingPathComponent("running")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = """
        #!/bin/sh
        case "$1" in
          status) test -f "\(state.path)" ;;
          start) touch "\(state.path)" ;;
          stop) rm -f "\(state.path)" ;;
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
