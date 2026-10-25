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
