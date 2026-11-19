import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func knownPortsSayWhatTheyAreAndWhetherABrowserHelps() {
    #expect(KnownPort.lookup(containerPort: 8080)?.opensInBrowser == true)
    #expect(KnownPort.lookup(containerPort: 1433)?.name == "SQL Server")
    #expect(KnownPort.lookup(containerPort: 1433)?.opensInBrowser == false)
    #expect(KnownPort.lookup(containerPort: 5005)?.opensInBrowser == false)
    #expect(KnownPort.lookup(containerPort: 10000)?.name == "Azure Blob storage")
    #expect(KnownPort.lookup(containerPort: 12345) == nil)
}

@Test func portMappingsPairHostAndContainerPortsWithoutDuplicates() throws {
    // Arrange
    let json = """
    {"Id":"a","Names":["/x"],"Image":"i","State":"running","Status":"Up","Created":1,
     "Ports":[{"PublicPort":8389,"PrivatePort":8080,"Type":"tcp"},{"PublicPort":8389,"PrivatePort":8080,"Type":"tcp"},
              {"PublicPort":5389,"PrivatePort":5005,"Type":"tcp"},{"PrivatePort":10002,"Type":"tcp"}]}
    """

    // Act
    let row = ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: nil)

    // Assert
    #expect(row.portMappings.map(\.host) == [5389, 8389])
    #expect(row.portMappings.map(\.container) == [5005, 8080])
    #expect(row.ports == [5389, 8389])
}

@Test func spokenSummaryNamesStateUptimeAndPorts() throws {
    // Arrange
    let json = """
    {"Id":"a","Names":["/shop-web-1"],"Image":"web","State":"running","Status":"Up 2 minutes (healthy)","Created":1,
     "Labels":{"com.docker.compose.service":"web"},
     "Ports":[{"PublicPort":8389,"PrivatePort":8080,"Type":"tcp"},{"PublicPort":5389,"PrivatePort":5005,"Type":"tcp"}]}
    """
    let running = ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: Date(timeIntervalSinceNow: -3_660))
    let stopped = ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.replacingOccurrences(of: "\"running\"", with: "\"exited\"").replacingOccurrences(of: "Up 2 minutes (healthy)", with: "Exited (137) 3 hours ago").utf8)), startedAt: nil)

    // Act & Assert
    #expect(running.spokenSummary() == "web, running, up 1h 1m, port 5389 Debugger, port 8389 Web")
    #expect(stopped.spokenSummary() == "web, stopped, Exited (137) 3 hours ago, port 5389 Debugger, port 8389 Web")
}
