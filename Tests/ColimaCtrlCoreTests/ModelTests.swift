import Foundation
import Testing
@testable import ColimaCtrlCore

private func container(state: String = "running", status: String = "Up 2 minutes (healthy)") throws -> ContainerRow {
    let json = """
    {"Id":"abc","Names":["/shop-web-1"],"Image":"web","State":"\(state)","Status":"\(status)","Created":1,
     "Labels":{"com.docker.compose.project":"shop","com.docker.compose.service":"web"},
     "Ports":[{"PublicPort":8080},{"PublicPort":8080},{"PrivatePort":5432}],
     "NetworkSettings":{"Networks":{"bridge":{},"app":{}}}}
    """
    return ContainerRow(try JSONDecoder().decode(APIContainer.self, from: Data(json.utf8)), startedAt: Date(timeIntervalSince1970: 9))
}

@Test func containerRowReadsComposeLabelsHealthAndUniquePorts() throws {
    let row = try container()
    #expect(row.name == "shop-web-1")
    #expect(row.project == "shop" && row.service == "web" && row.title == "web")
    #expect(row.health == "healthy" && row.display == .running)
    #expect(row.ports == [8080])
    #expect(row.networks == ["app", "bridge"])
    #expect(row.startedAt != nil)
}

@Test func stoppedContainersHaveNoStartTime() throws {
    let row = try container(state: "exited", status: "Exited (0) 1 hour ago")
    #expect(row.startedAt == nil && row.display == .stopped && !row.isRunning)
}

@Test func fleetHealthIsTheWorstRunningState() throws {
    let healthy = try container()
    let unhealthy = try container(status: "Up 1 minute (unhealthy)")
    let starting = try container(status: "Up 3 seconds (health: starting)")
    let stopped = try container(state: "exited", status: "Exited (0) 1 hour ago")
    #expect(FleetHealth([stopped]) == .idle)
    #expect(FleetHealth([healthy, stopped]) == .healthy)
    #expect(FleetHealth([healthy, starting]) == .starting)
    #expect(FleetHealth([healthy, starting, unhealthy]) == .unhealthy)
}

@Test func dfDecodesTheFlatAndNestedEngineFormats() throws {
    let image = #"{"Id":"sha256:a","RepoTags":["x:1"],"Size":10,"Created":1,"Containers":0}"#
    let flat = try JSONDecoder().decode(APIDf.self, from: Data(#"{"Images":[\#(image)],"Volumes":[],"BuildCache":[],"Containers":[]}"#.utf8))
    let nested = try JSONDecoder().decode(APIDf.self, from: Data(#"{"ImageUsage":{"Items":[\#(image)]},"VolumeUsage":{"Items":[]}}"#.utf8))
    #expect(flat.allImages.count == 1 && nested.allImages.count == 1)
    #expect(nested.allVolumes.isEmpty)
}

@Test func inspectDecodesPortsMountsAndEnvironment() throws {
    let json = """
    {"Id":"abc123","Created":"2026-10-25T21:32:20.349132781Z","Path":"nginx","Args":["-g","daemon off;"],
     "Config":{"Image":"nginx:alpine","Env":["PATH=/bin","EMPTY="]},
     "State":{"StartedAt":"2026-10-25T21:32:21Z","Health":{"Status":"healthy"}},
     "HostConfig":{"RestartPolicy":{"Name":""}},
     "Mounts":[{"Type":"volume","Name":"data","Destination":"/data","RW":false}],
     "NetworkSettings":{"Ports":{"80/tcp":[{"HostPort":"18080"},{"HostPort":"18080"}],"443/tcp":null},"Networks":{"bridge":{"IPAddress":"172.17.0.2"}}}}
    """
    let inspect = ContainerInspect(try JSONDecoder().decode(APIInspect.self, from: Data(json.utf8)))
    #expect(inspect.command == "nginx -g daemon off;")
    #expect(inspect.restartPolicy == "no")
    #expect(inspect.ports.map(\.host) == [18080])
    #expect(inspect.mounts.first?.readOnly == true)
    #expect(inspect.env.map(\.key) == ["PATH", "EMPTY"] && inspect.env[1].value == "")
    #expect(inspect.attachments.first?.address == "172.17.0.2")
}

@Test func inspectDecodesLabelsRestartCountAndExitState() throws {
    // Arrange
    let json = """
    {"Id":"abc","Created":"2026-10-25T21:32:20Z","Path":"app","Args":[],"RestartCount":3,
     "Config":{"Image":"app","Env":["PATH=/bin","EMPTY="],"Labels":{"z":"1","com.docker.compose.project":"demo"}},
     "State":{"StartedAt":"2026-10-25T21:32:21Z","ExitCode":137,"OOMKilled":true}}
    """

    // Act
    let inspect = ContainerInspect(try JSONDecoder().decode(APIInspect.self, from: Data(json.utf8)))

    // Assert
    #expect(inspect.labels.map(\.key) == ["com.docker.compose.project", "z"])
    #expect(inspect.restartCount == 3)
    #expect(inspect.exitCode == 137)
    #expect(inspect.oomKilled)
    #expect(ContainerInspect.envFile(inspect.env) == "PATH=/bin\nEMPTY=")
}

@Test func networksSortBySubnetWithMissingSubnetsFirst() {
    // Arrange
    let withSubnet = NetworkRow(id: "1", name: "a", driver: "bridge", scope: "local", isInternal: false, subnet: "172.17.0.0/16")
    let without = NetworkRow(id: "2", name: "b", driver: "host", scope: "local", isInternal: false, subnet: nil)

    // Act
    let sorted = [withSubnet, without].sorted { $0.subnetKey < $1.subnetKey }

    // Assert
    #expect(sorted.map(\.id) == ["2", "1"])
}

@Test func displayStatesHaveSpokenLabels() throws {
    // Arrange
    let unhealthy = try container(status: "Up 1 minute (unhealthy)")
    let stopped = try container(state: "exited", status: "Exited (0) 1 hour ago")

    // Act & Assert
    #expect(unhealthy.display.label == "Unhealthy")
    #expect(stopped.display.label == "Stopped")
    #expect(Set([DisplayState.running, .starting, .restarting, .unhealthy, .paused, .stopped].map(\.label)).count == 6)
}

@Test func diskUsageSumsReclaimableSpaceAcrossBuckets() {
    // Arrange
    let usage = DiskUsage(
        images: DiskBucket(count: 1, size: 100, reclaimable: 40),
        containers: DiskBucket(count: 1, size: 10, reclaimable: 5),
        volumes: DiskBucket(count: 1, size: 50, reclaimable: 20),
        buildCache: DiskBucket(count: 1, size: 40, reclaimable: 35)
    )

    // Act & Assert
    #expect(usage.reclaimable == 100)
    #expect(usage.total == 200)
}

@MainActor @Test func logModelKeepsTheRequestedNumberOfLines() {
    // Arrange
    let model = LogModel(client: DockerClient(socketPath: "/nonexistent.sock"), containerID: "abc", capacity: 1234)

    // Act & Assert
    #expect(model.capacity == 1234)
    #expect(LogModel.defaultCapacity == 5000)
}

@Test func resumingUsesTheEnginesUnpauseEndpoint() {
    // Act & Assert
    #expect(ContainerAction.resume.endpoint == "unpause")
    #expect(ContainerAction.pause.endpoint == "pause")
    #expect(ContainerAction.restart.endpoint == "restart")
}

@Test func inspectDecodesTheHealthCheckLog() throws {
    // Arrange
    let json = """
    {"Id":"abc","Created":"2026-10-25T21:32:20Z","Path":"app","Args":[],
     "Config":{"Image":"app"},
     "State":{"StartedAt":"2026-10-25T21:32:21Z","Health":{"Status":"unhealthy","FailingStreak":3,"Log":[
       {"End":"2026-10-25T21:33:00.123456789Z","ExitCode":0,"Output":"ok\\n"},
       {"End":"2026-10-25T21:33:30Z","ExitCode":1,"Output":"  curl: (7) connection refused\\n"}]}}}
    """

    // Act
    let inspect = ContainerInspect(try JSONDecoder().decode(APIInspect.self, from: Data(json.utf8)))

    // Assert
    #expect(inspect.health == "unhealthy")
    #expect(inspect.failingStreak == 3)
    #expect(inspect.healthChecks.map(\.exitCode) == [0, 1])
    #expect(inspect.healthChecks.last?.output == "curl: (7) connection refused")
    #expect(inspect.healthChecks.last?.date != nil)
}
