import SwiftUI
import ColimaCtrlCore

extension PruneKind {
    var title: String {
        switch self {
        case .containers: "Remove all stopped containers?"
        case .imagesDangling: "Remove dangling images?"
        case .imagesUnused: "Remove every image not used by a container?"
        case .volumes: "Delete ALL volumes not attached to a container?"
        case .buildCache: "Clear the entire build cache?"
        }
    }

    var warning: String { self == .volumes ? "Their data is lost." : "This can't be undone." }
}

private struct PruneConfirmation: ViewModifier {
    @Environment(FleetStore.self) private var store
    @Binding var kind: PruneKind?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            kind?.title ?? "", isPresented: Binding(get: { kind != nil }, set: { if !$0 { kind = nil } }), titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { if let kind { store.prune(kind) } }
        } message: {
            Text(kind?.warning ?? "")
        }
    }
}

extension View {
    func pruneConfirmation(_ kind: Binding<PruneKind?>) -> some View { modifier(PruneConfirmation(kind: kind)) }
}

struct Tag: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(.quaternary, in: .capsule)
    }
}

struct VolumesView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var sortOrder = [KeyPathComparator(\VolumeRow.size, order: .reverse)]
    @State private var prune: PruneKind?
    @State private var removal: VolumeRow?

    var body: some View {
        let rows = store.volumes.filter { ui.filter.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.filter) || ($0.project ?? "").localizedCaseInsensitiveContains(ui.filter) }
            .sorted(using: sortOrder)
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedVolumeID, sortOrder: $sortOrder) {
            TableColumn("Volume", value: \.name) { volume in
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name).lineLimit(1).truncationMode(.middle)
                    if let project = volume.project { Text(project).font(.caption).foregroundStyle(.secondary) }
                }
            }
            TableColumn("Status") { Tag($0.refs > 0 ? "in use · \($0.refs)" : "unused") }.width(100)
            TableColumn("Size", value: \.size) { Text(Format.bytes($0.size)).monospacedDigit() }.width(90)
            TableColumn("") { volume in Button("Remove", systemImage: "trash") { removal = volume }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.red) }.width(36)
        }
        .scrollContentBackground(.hidden)
        .toolbar { ToolbarItem { Button("Prune unused", systemImage: "trash") { prune = .volumes }.tint(.red).help("Delete all unused volumes") } }
        .pruneConfirmation($prune)
        .confirmationDialog("Delete volume \(removal?.name ?? "")?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let removal { store.remove(volume: removal.name) } }
        } message: {
            Text("Its data is lost.")
        }
        .overlay { if rows.isEmpty { ContentUnavailableView("No volumes", systemImage: "cylinder") } }
    }
}

struct ImagesView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var sortOrder = [KeyPathComparator(\ImageRow.size, order: .reverse)]
    @State private var prune: PruneKind?
    @State private var removal: ImageRow?

    var body: some View {
        let rows = store.images.filter { ui.filter.isEmpty || $0.title.localizedCaseInsensitiveContains(ui.filter) }.sorted(using: sortOrder)
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedImageID, sortOrder: $sortOrder) {
            TableColumn("Image", value: \.title) { Text($0.title).lineLimit(1).truncationMode(.middle) }
            TableColumn("Status") { Tag($0.containers > 0 ? "in use · \($0.containers)" : "unused") }.width(100)
            TableColumn("Size", value: \.size) { Text(Format.bytes($0.size)).monospacedDigit() }.width(90)
            TableColumn("Created", value: \.created) { Text(Format.ago($0.created)).foregroundStyle(.secondary) }.width(110)
            TableColumn("") { image in Button("Remove", systemImage: "trash") { removal = image }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.red) }.width(36)
        }
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem {
                Menu("Prune", systemImage: "trash") {
                    Button("Dangling images") { prune = .imagesDangling }
                    Button("All unused images") { prune = .imagesUnused }
                }.tint(.red)
            }
        }
        .pruneConfirmation($prune)
        .confirmationDialog("Remove image \(removal?.title ?? "")?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let removal { store.remove(image: removal.id) } }
        }
        .overlay { if rows.isEmpty { ContentUnavailableView("No images", systemImage: "square.stack.3d.up") } }
    }
}

struct NetworksView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui

    var body: some View {
        let rows = store.networks.filter { ui.filter.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.filter) || ($0.subnet ?? "").contains(ui.filter) }
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedNetworkID) {
            TableColumn("Network") { network in
                HStack(spacing: 6) {
                    Text(network.name)
                    if network.isBuiltIn { Tag("built-in") }
                    if network.isInternal { Tag("internal") }
                }
            }
            TableColumn("Driver") { Text("\($0.driver) · \($0.scope)").foregroundStyle(.secondary) }.width(130)
            TableColumn("Subnet") { Text($0.subnet ?? "").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary) }.width(150)
            TableColumn("Containers") { network in
                Text(store.containers.filter { $0.networks.contains(network.name) }.count, format: .number).monospacedDigit()
            }.width(90)
        }
        .scrollContentBackground(.hidden)
        .overlay { if rows.isEmpty { ContentUnavailableView("No networks", systemImage: "point.3.connected.trianglepath.dotted") } }
    }
}

struct SystemView: View {
    @Environment(FleetStore.self) private var store
    @State private var prune: PruneKind?

    var body: some View {
        ScrollView {
            if let disk = store.disk {
                let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]
                LazyVGrid(columns: columns, spacing: 14) {
                    SelfCard()
                    Summary(title: "Docker disk", value: disk.total, detail: "images, containers, volumes, build cache")
                    Summary(title: "Images", value: disk.images.size, detail: detail(disk.images), action: ("Prune unused", .imagesUnused), prune: $prune)
                    Summary(title: "Containers", value: disk.containers.size, detail: detail(disk.containers), action: ("Prune stopped", .containers), prune: $prune)
                    Summary(title: "Volumes", value: disk.volumes.size, detail: detail(disk.volumes), action: ("Prune unused", .volumes), prune: $prune)
                    Summary(title: "Build cache", value: disk.buildCache.size, detail: "\(disk.buildCache.count) entries · \(Format.bytes(disk.buildCache.reclaimable)) reclaimable", action: ("Prune", .buildCache), prune: $prune)
                }
                .padding(20)
            } else {
                ProgressView().padding(40)
            }
        }
        .pruneConfirmation($prune)
    }

    private func detail(_ bucket: DiskBucket) -> String { "\(bucket.count) total · \(Format.bytes(bucket.reclaimable)) reclaimable" }
}

private struct SelfCard: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        let metrics = store.selfMetrics
        VStack(alignment: .leading, spacing: 4) {
            Text("Colima Ctrl").font(.caption).foregroundStyle(.secondary)
            Text(Format.bytes(Int64(metrics.memory))).font(.title2.weight(.semibold))
            Text("\(metrics.cpu, format: .number.precision(.fractionLength(1)))% CPU · this app").font(.caption).foregroundStyle(.secondary)
            Sparkline(values: metrics.series.cpu, maximum: max(10, metrics.series.cpu.max() ?? 10), color: Brand.green).frame(height: 30).padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentCard(cornerRadius: 18)
    }
}

private struct Summary: View {
    let title: String
    let value: Int64
    let detail: String
    var action: (String, PruneKind)?
    var prune: Binding<PruneKind?>?

    init(title: String, value: Int64, detail: String, action: (String, PruneKind)? = nil, prune: Binding<PruneKind?>? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
        self.action = action
        self.prune = prune
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Format.bytes(value)).font(.title2.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if let action, let prune {
                Button(action.0) { prune.wrappedValue = action.1 }.buttonStyle(.glass).controlSize(.small).tint(.red).padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentCard(cornerRadius: 18)
    }
}
