import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func dockerExecScriptTargetsTheColimaSocketAndContainer() {
    // Arrange
    let socket = "/Users/me/.colima/default/docker.sock"

    // Act
    let script = ShellCommand.dockerExecScript(socketPath: socket, containerID: "abc123")

    // Assert
    #expect(script.contains("DOCKER_HOST='unix:///Users/me/.colima/default/docker.sock'"))
    #expect(script.contains("docker exec -it 'abc123'"))
    #expect(script.hasPrefix("#!/bin/zsh"))
}

@Test func quotingEscapesSingleQuotes() {
    // Arrange
    let value = "it's a path"

    // Act
    let quoted = ShellCommand.quote(value)

    // Assert
    #expect(quoted == #"'it'\''s a path'"#)
}
