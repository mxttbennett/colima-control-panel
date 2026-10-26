import SwiftUI
import ColimaCtrlCore

struct PaneHeader<Actions: View>: View {
    @Environment(UIState.self) private var ui
    let title: String
    let subtitle: String?
    let copy: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.title3.weight(.semibold)).lineLimit(2)
                CopyButton(text: copy)
                Spacer()
                Button("Close", systemImage: "xmark") { ui.closePane() }.labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(1) }
            HStack(spacing: 8) { actions }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

struct UsedBy: View {
    @Environment(UIState.self) private var ui
    let title: String
    let containers: [ContainerRow]

    var body: some View {
        Card(title) {
            if containers.isEmpty {
                Text("No containers").foregroundStyle(.secondary)
            } else {
                ForEach(containers) { container in
                    Button { ui.show(container.id) } label: {
                        HStack(spacing: 8) {
                            StatusDot(color: container.display.color, size: 8)
                            Text(container.title).lineLimit(1)
                            Spacer()
                            Text(container.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PaneBody<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) { content }
                .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }
}

struct VolumeDetailView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let name: String
    @State private var detail: VolumeDetail?
    @State private var confirmRemove = false

    var body: some View {
        if let row = store.volumes.first(where: { $0.name == name }) {
            VStack(spacing: 0) {
                PaneHeader(title: row.name, subtitle: row.project, copy: row.name) {
                    Button("Remove", role: .destructive) { confirmRemove = true }.tint(.red)
                }
                PaneBody {
                    Card("Overview") {
                        Field("Size", Format.bytes(row.size))
                        Field("Status", row.refs > 0 ? "in use · \(row.refs)" : "unused")
                        if let detail {
                            Field("Driver", detail.driver)
                            Field("Scope", detail.scope)
                            Field("Mountpoint", detail.mountpoint, copy: true)
                            if let created = detail.created { Field("Created", Format.ago(created)) }
                        }
                    }
                    UsedBy(title: "Used by", containers: store.containers.filter { $0.volumes.contains(name) })
                    if let detail, !detail.labels.isEmpty {
                        Card("Labels") { ForEach(detail.labels) { Field($0.key, $0.value, copy: true) } }
                    }
                }
            }
            .task(id: name) { detail = try? await store.inspectVolume(name) }
            .confirmationDialog("Delete volume \(row.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { store.remove(volume: row.name); ui.closePane() }
            } message: {
                Text("Its data is lost.")
            }
        }
    }
}

struct ImageDetailView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let id: String
    @State private var detail: ImageDetail?
    @State private var confirmRemove = false
    @State private var revealed: Set<String> = []

    var body: some View {
        if let row = store.images.first(where: { $0.id == id }) {
            VStack(spacing: 0) {
                PaneHeader(title: row.title, subtitle: String(row.id.replacingOccurrences(of: "sha256:", with: "").prefix(12)), copy: row.tags.first ?? row.id) {
                    Button("Remove", role: .destructive) { confirmRemove = true }.tint(.red)
                }
                PaneBody {
                    Card("Overview") {
                        Field("Size", Format.bytes(row.size))
                        Field("Created", Format.ago(row.created))
                        Field("Status", row.containers > 0 ? "in use · \(row.containers)" : "unused")
                        Field("ID", String(row.id.replacingOccurrences(of: "sha256:", with: "").prefix(12)), copy: row.id)
                        if let detail {
                            if !detail.digest.isEmpty { Field("Digest", detail.digest, copy: true) }
                            if !detail.architecture.isEmpty { Field("Platform", "\(detail.os)/\(detail.architecture)") }
                            if !detail.entrypoint.isEmpty { Field("Entrypoint", detail.entrypoint, copy: true) }
                            if !detail.command.isEmpty { Field("Command", detail.command, copy: true) }
                        }
                    }
                    if row.tags.count > 1 {
                        Card("Tags") { ForEach(row.tags, id: \.self) { Field("Tag", $0, copy: true) } }
                    }
                    UsedBy(title: "Used by", containers: store.containers.filter { $0.imageID == id })
                    if let detail, !detail.exposedPorts.isEmpty {
                        Card("Exposed ports") { ForEach(detail.exposedPorts, id: \.self) { Text($0).font(.system(size: 12, design: .monospaced)) } }
                    }
                    if let detail, !detail.env.isEmpty {
                        Card("Environment") { ForEach(detail.env) { EnvRow(key: $0.key, value: $0.value, revealed: $revealed) } }
                    }
                }
            }
            .task(id: id) { detail = try? await store.inspectImage(id) }
            .confirmationDialog("Remove image \(row.title)?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { store.remove(image: row.id); ui.closePane() }
            }
        }
    }
}

struct NetworkDetailView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let id: String
    @State private var detail: NetworkDetail?
    @State private var confirmRemove = false

    var body: some View {
        if let row = store.networks.first(where: { $0.id == id }) {
            VStack(spacing: 0) {
                PaneHeader(title: row.name, subtitle: row.isBuiltIn ? "Built-in network" : nil, copy: row.name) {
                    if !row.isBuiltIn { Button("Remove", role: .destructive) { confirmRemove = true }.tint(.red) }
                }
                PaneBody {
                    Card("Overview") {
                        Field("Driver", row.driver)
                        Field("Scope", row.scope)
                        if let subnet = detail?.subnet ?? row.subnet { Field("Subnet", subnet, copy: true) }
                        if let gateway = detail?.gateway { Field("Gateway", gateway, copy: true) }
                        if row.isInternal { Field("Internal", "yes") }
                        if let detail {
                            if detail.ipv6 { Field("IPv6", "enabled") }
                            if let created = detail.created { Field("Created", Format.ago(created)) }
                        }
                    }
                    Card("Connected containers") {
                        if let members = detail?.members, !members.isEmpty {
                            ForEach(members) { member in
                                Button {
                                    if store.containers.contains(where: { $0.id == member.id }) { ui.show(member.id) }
                                } label: {
                                    HStack {
                                        Text(member.name).lineLimit(1)
                                        Spacer()
                                        Text(member.address).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("None").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .task(id: id) { detail = try? await store.inspectNetwork(id) }
            .confirmationDialog("Remove network \(row.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { store.remove(network: row.id); ui.closePane() }
            } message: {
                Text("Containers using it must be stopped first.")
            }
        }
    }
}
