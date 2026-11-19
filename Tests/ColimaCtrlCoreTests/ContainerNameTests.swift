import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func aValidNameHasNoProblem() {
    // Act
    let problem = ContainerName.problem(with: "web_1.api-v2", current: "web", others: ["db"])

    // Assert
    #expect(problem == nil)
}

@Test func namesDockerRefusesComeBackWithAReason() {
    // Act & Assert
    #expect(ContainerName.problem(with: "a", current: "web", others: []) == "Use at least 2 characters.")
    #expect(ContainerName.problem(with: "-web", current: "web", others: []) == "Start with a letter or number.")
    #expect(ContainerName.problem(with: "my app", current: "web", others: []) == "Use only letters, numbers, underscores, periods and hyphens.")
    #expect(ContainerName.problem(with: "café", current: "web", others: []) == "Use only letters, numbers, underscores, periods and hyphens.")
}

@Test func theCurrentOrATakenNameIsRejected() {
    // Act & Assert
    #expect(ContainerName.problem(with: "web", current: "web", others: ["db"]) == "That is already its name.")
    #expect(ContainerName.problem(with: "db", current: "web", others: ["db"]) == "Another container already uses that name.")
}
