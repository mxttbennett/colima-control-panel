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
                Picker("", selection: $ui.detailTab) {
                    ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 16).padding(.bottom, 10)
                switch ui.detailTab {
                case .info: InfoTab(row: row).id(row.id)
                case .logs: LogsTab(containerID: row.id).id(row.id)
                }
            }
        }
    }
}

private struct DetailHeader: View {
    @Environment(FleetStore.self) private var store
    let row: ContainerRow
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatusDot(color: row.display.color)
                Text(row.name).font(.title3.weight(.semibold)).lineLimit(1)
                CopyButton(text: row.name)
            }
            Group {
                if row.state == "running", let started = row.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { Text("Up \(Format.uptime(since: started, now: $0.date))") }
                } else {
                    Text(row.status)
                }
            }
            .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Group {
                    if row.isRunning {
                        Button("Restart") { store.perform(.restart, on: [row.id]) }
                        Button("Stop") { store.perform(.stop, on: [row.id]) }
                    } else {
                        Button("Start") { store.perform(.start, on: [row.id]) }
                    }
                    Button("Remove", role: .destructive) { confirmRemove = true }
                }
                .buttonStyle(.bordered)
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
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                copied = false
            }
        }
        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary).help("Copy")
    }
}
