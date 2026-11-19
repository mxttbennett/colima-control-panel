import Foundation
import Testing
@testable import ColimaCtrlCore

private func makeRoot(_ names: [String], files: [String] = []) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(path: "ccp-profiles-\(UUID().uuidString)")
    for name in names { try FileManager.default.createDirectory(at: root.appending(path: name), withIntermediateDirectories: true) }
    for file in files { FileManager.default.createFile(atPath: root.appending(path: file).path, contents: Data()) }
    return root
}

@Test func profilesAreTheNonInternalDirectoriesPlusDefault() throws {
    // Arrange
    let root = try makeRoot(["work", "_lima", "_store", ".hidden", "default"], files: ["docker.sock", "ssh_config"])
    defer { try? FileManager.default.removeItem(at: root) }

    // Act
    let profiles = ColimaProfile.available(in: root)

    // Assert
    #expect(profiles == ["default", "work"])
}

@Test func defaultIsListedEvenWhenItsDirectoryIsMissing() throws {
    // Arrange
    let root = try makeRoot(["staging"])
    defer { try? FileManager.default.removeItem(at: root) }

    // Act & Assert
    #expect(ColimaProfile.available(in: root) == ["default", "staging"])
    #expect(ColimaProfile.available(in: root.appending(path: "missing")) == ["default"])
}
