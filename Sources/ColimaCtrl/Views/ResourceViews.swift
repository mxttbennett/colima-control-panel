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

    var paletteName: String {
        switch self {
        case .containers: "stopped containers"
        case .imagesDangling: "dangling images"
        case .imagesUnused: "unused images"
        case .volumes: "unused volumes"
        case .buildCache: "build cache"
        }
    }
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
        Text(text).zoomFont(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(.quaternary, in: .capsule)
    }
}

struct VolumesView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var sortOrder = [KeyPathComparator(\VolumeRow.size, order: .reverse)]
    @State private var prune: PruneKind?
    @State private var removals: [VolumeRow] = []

    var body: some View {
        let rows = store.volumes.filter { ui.filter.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.filter) || ($0.project ?? "").localizedCaseInsensitiveContains(ui.filter) }
            .sorted(using: sortOrder)
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedVolumeIDs, sortOrder: $sortOrder) {
            TableColumn("Volume", value: \.name) { volume in
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name).lineLimit(1).truncationMode(.middle)
                    if let project = volume.project { Text(project).zoomFont(.caption).foregroundStyle(.secondary) }
                }
            }
            TableColumn("Status") { Tag($0.refs > 0 ? "in use · \($0.refs)" : "unused") }.width(100)
            TableColumn("Size", value: \.size) { Text(Format.bytes($0.size)).monospacedDigit() }.width(90)
            TableColumn("") { volume in Button("Remove", systemImage: "trash") { removals = [volume] }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.red) }.width(36)
        }
        .scrollContentBackground(.hidden)
        .deselectsOnReclick()
        .zoomFont(.system(size: 13))
        .contextMenu(forSelectionType: String.self) { names in
            let picked = rows.filter { names.contains($0.name) }
            if let volume = picked.first, picked.count == 1 {
                Button("Copy Name") { Clipboard.copy(volume.name) }
                if let user = store.containers.first(where: { $0.volumes.contains(volume.name) }) {
                    Button("Show Container \(user.title)") { ui.show(user.id) }
                }
                Divider()
                Button("Delete…", role: .destructive) { removals = [volume] }
            } else if picked.count > 1 {
                Button("Copy \(picked.count) Names") { Clipboard.copy(picked.map(\.name).joined(separator: "\n")) }
                let unused = picked.filter { $0.refs == 0 }
                if !unused.isEmpty {
                    Divider()
                    Button(unused.count == picked.count ? "Delete \(picked.count) Volumes…" : "Delete \(unused.count) Unused Volumes…", role: .destructive) { removals = unused }
                }
            }
        }
        .toolbar { ToolbarItem { Button("Prune unused", systemImage: "trash") { prune = .volumes }.tint(.red).help("Delete all unused volumes") } }
        .pruneConfirmation($prune)
        .confirmationDialog(removals.count == 1 ? "Delete volume \(removals[0].name)?" : "Delete \(removals.count) volumes?", isPresented: Binding(get: { !removals.isEmpty }, set: { if !$0 { removals = [] } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { store.remove(volumes: removals.map(\.name)) }
        } message: {
            Text("Their data is lost.")
        }
        .overlay {
            if !store.hasLoaded { ProgressView("Loading volumes…") } else if rows.isEmpty { if store.volumes.isEmpty { ContentUnavailableView("No volumes", systemImage: "cylinder") } else { NoMatches(what: "volumes") } }
        }
    }
}
