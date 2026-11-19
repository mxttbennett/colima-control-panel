import SwiftUI
import ColimaCtrlCore

struct ContainerDetailView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let id: String

    var body: some View {
        @Bindable var ui = ui
        if let row = store.containers.first(where: { $0.id == id }) {
            VStack(spacing: 0) {
                DetailHeader(row: row)
                GlassSegmented(options: DetailTab.allCases, selection: $ui.detailTab) { $0.rawValue }
                    .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.bottom, 10)
                Group {
                    switch ui.detailTab {
                    case .info: InfoTab(row: row).id(row.id).transition(.opacity)
                    case .logs: LogsTab(containerID: row.id).id(row.id).transition(.opacity)
                    }
                }
                .motion(Motion.quick, value: ui.detailTab)
            }
        }
    }
}

private struct DetailHeader: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let row: ContainerRow
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if store.pending[row.id] != nil { ProgressView().controlSize(.mini).frame(width: 9, height: 9) } else { StatusDot(color: row.display.color, label: row.display.label) }
                Text(row.name).zoomFont(.title3.weight(.semibold)).lineLimit(1).textSelection(.enabled)
                CopyButton(text: row.name)
                Spacer()
                Button("Close", systemImage: "xmark") { ui.closePane() }.labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Group {
                if let pending = store.pending[row.id] {
                    Text(pending.label)
                } else if row.state == "running", let started = row.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { Text("Up \(Uptime.text(since: started, now: $0.date))") }
                } else {
                    Text(row.status)
                }
            }
            .zoomFont(.callout).foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 8) {
              HStack(spacing: 8) {
                Group {
                    if row.isRunning {
                        Button("Restart") { store.perform(.restart, on: [row.id]) }
                        Button("Stop") { store.perform(.stop, on: [row.id]) }
                        Button("Shell", systemImage: "terminal") { openContainerShell(row, store: store) }.help("Open a shell in Terminal")
                    } else {
                        Button("Start") { store.perform(.start, on: [row.id]) }
                    }
                    Button("Remove", role: .destructive) { confirmRemove = true }.buttonStyle(.liquid(tint: .red))
                }
                .buttonStyle(.liquid)
                .disabled(store.pending[row.id] != nil)
              }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .confirmationDialog("Remove \(row.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { store.remove(container: row.id) }
        } message: {
            Text("Running containers are force-stopped.")
        }
    }
}

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
            Clipboard.copy(text)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                copied = false
            }
        }
        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary).help("Copy")
    }
}

struct MultiSelectionPane: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui

    var body: some View {
        let ids = Array(ui.selectedContainerIDs)
        let rows = store.containers.filter { ui.selectedContainerIDs.contains($0.id) }
        let busy = ids.contains { store.pending[$0] != nil }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(rows.count) containers selected").zoomFont(.title3.weight(.semibold))
                Spacer()
                Button("Close", systemImage: "xmark") { ui.closePane() }.labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Text("\(rows.filter(\.isRunning).count) running, \(rows.filter { !$0.isRunning }.count) stopped")
                .zoomFont(.callout).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Start") { store.perform(.start, on: ids) }
                Button("Restart") { store.perform(.restart, on: ids) }
                Button("Stop") { store.perform(.stop, on: ids) }
                Button("Remove", role: .destructive) {
                    ui.confirm = ConfirmRequest(title: "Remove \(rows.count) selected containers?", message: "Running containers are force-stopped.", button: "Remove \(rows.count) Containers") {
                        store.remove(containers: ids)
                        ui.closePane()
                    }
                }.buttonStyle(.liquid(tint: .red))
            }
            .buttonStyle(.liquid).disabled(busy)
            List(rows) { row in
                HStack(spacing: 8) {
                    StatusDot(color: row.display.color, label: row.display.label)
                    Text(row.title).lineLimit(1)
                }
            }
            .listStyle(.plain)
        }
        .padding(16)
    }
}
