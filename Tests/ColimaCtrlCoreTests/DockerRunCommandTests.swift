import Foundation
import Testing
@testable import ColimaCtrlCore

private func inspect(_ json: String) throws -> ContainerInspect {
    ContainerInspect(try JSONDecoder().decode(APIInspect.self, from: Data(json.utf8)))
}

private let sample = """
{"Id":"abc","Created":"2026-10-25T21:32:20Z","Path":"app","Args":[],"RestartCount":0,
 "Config":{"Image":"acme/api:2.4","Env":["PATH=/bin","LOG_LEVEL=info","TOKEN=it's secret"],"Labels":{}},
 "State":{"StartedAt":"2026-10-25T21:32:21Z"},
 "HostConfig":{"RestartPolicy":{"Name":"unless-stopped"},"Memory":536870912,"NanoCpus":1500000000},
 "Mounts":[{"Type":"volume","Name":"data","Destination":"/data","RW":true},{"Type":"bind","Source":"/src","Destination":"/app","RW":false}],
 "NetworkSettings":{"Ports":{"3000/tcp":[{"HostPort":"3000"}]},"Networks":{"shop_default":{"IPAddress":"172.20.0.3"}}}}
"""

@Test func inspectReadsMemoryAndCPULimits() throws {
    // Arrange & Act
    let detail = try inspect(sample)

    // Assert
    #expect(detail.memoryLimit == 536_870_912)
    #expect(detail.cpuLimit == 1.5)
    #expect(try inspect(sample.replacingOccurrences(of: "\"Memory\":536870912,\"NanoCpus\":1500000000", with: "\"Memory\":0")).memoryLimit == nil)
}

@Test func dockerRunCommandRebuildsTheContainerFromItsInspectData() throws {
    // Arrange
    let detail = try inspect(sample)

    // Act
    let command = DockerRunCommand.make(name: "shop-api-1", inspect: detail)

    // Assert
    #expect(command.hasPrefix("docker run -d \\\n"))
    #expect(command.contains("--name 'shop-api-1'"))
    #expect(command.contains("--restart unless-stopped"))
    #expect(command.contains("--network 'shop_default'"))
    #expect(command.contains("--memory 536870912"))
    #expect(command.contains("--cpus 1.5"))
    #expect(command.contains("-p 3000:3000/tcp"))
    #expect(command.contains("-v 'data:/data'"))
    #expect(command.contains("-v '/src:/app:ro'"))
    #expect(command.contains(#"-e 'TOKEN=it'\''s secret'"#))
    #expect(!command.contains("PATH="))
    #expect(command.hasSuffix("'acme/api:2.4'"))
}

private let jsonClient = DockerClient(socketPath: DockerClient.defaultSocketPath())

@MainActor @Test(.enabled(if: jsonClient.socketExists)) func inspectJSONFromTheEngineIsIndentedAndSorted() async throws {
    // Arrange
    let store = FleetStore(client: jsonClient)
    let list = try await jsonClient.get("/containers/json?all=1", as: [APIContainer].self)
    guard let first = list.first else { return }

    // Act
    let text = try await store.inspectJSON(first.id)

    // Assert
    #expect(text.hasPrefix("{\n"))
    #expect(text.contains("\"Id\" : \"\(first.id)\""))
}
