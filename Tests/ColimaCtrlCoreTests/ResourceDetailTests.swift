import Foundation
import Testing
@testable import ColimaCtrlCore

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

@Test func containerRowsKnowTheirImageAndVolumes() throws {
    let json = """
    {"Id":"abc","Names":["/db"],"Image":"mssql","ImageID":"sha256:111","State":"running","Status":"Up","Created":1,
     "Mounts":[{"Type":"volume","Name":"data"},{"Type":"bind","Name":null},{"Type":"volume","Name":"logs"}]}
    """
    let row = ContainerRow(try decode(APIContainer.self, json), startedAt: nil)
    #expect(row.imageID == "sha256:111")
    #expect(row.volumes == ["data", "logs"])
}

@Test func volumeDetailReadsDriverMountpointAndSortedLabels() throws {
    let json = """
    {"Name":"data","Driver":"local","Scope":"local","Mountpoint":"/var/lib/docker/volumes/data/_data",
     "CreatedAt":"2026-10-25T15:25:01-04:00","Labels":{"b":"2","a":"1"}}
    """
    let detail = VolumeDetail(try decode(APIVolumeInspect.self, json))
    #expect(detail.mountpoint.hasSuffix("/data/_data"))
    #expect(detail.labels.map(\.key) == ["a", "b"])
    #expect(detail.created != nil)
}

@Test func imageDetailJoinsEntrypointAndListsPorts() throws {
    let json = """
    {"Id":"sha256:1","RepoDigests":["x@sha256:2"],"Created":"2026-10-25T21:32:20.349132781Z","Size":10,"Architecture":"arm64","Os":"linux",
     "Config":{"Entrypoint":["/entry.sh"],"Cmd":["run","--fast"],"Env":["A=1","EMPTY="],"ExposedPorts":{"80/tcp":{},"443/tcp":{}}}}
    """
    let detail = ImageDetail(try decode(APIImageInspect.self, json))
    #expect(detail.entrypoint == "/entry.sh" && detail.command == "run --fast")
    #expect(detail.exposedPorts == ["443/tcp", "80/tcp"])
    #expect(detail.env.map(\.key) == ["A", "EMPTY"] && detail.env[1].value == "")
    #expect(detail.digest == "x@sha256:2")
}

@Test func networkDetailListsMembersByName() throws {
    let json = """
    {"Id":"n1","Name":"app","Driver":"bridge","Scope":"local","Internal":false,"EnableIPv6":false,
     "IPAM":{"Config":[{"Subnet":"172.18.0.0/16","Gateway":"172.18.0.1"}]},
     "Containers":{"c2":{"Name":"web","IPv4Address":"172.18.0.3/16"},"c1":{"Name":"api","IPv4Address":"172.18.0.2/16"}}}
    """
    let detail = NetworkDetail(try decode(APINetworkInspect.self, json))
    #expect(detail.members.map(\.name) == ["api", "web"])
    #expect(detail.subnet == "172.18.0.0/16" && detail.gateway == "172.18.0.1")
}
