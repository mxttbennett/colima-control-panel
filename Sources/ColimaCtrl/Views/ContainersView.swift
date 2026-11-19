import SwiftUI
import ColimaCtrlCore

struct ContainersView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(Preferences.self) private var prefs
    @State private var pendingRemoval: PendingContainerRemoval?
    @AppStorage("collapsedProjects") private var collapsedRaw = ""

    private var collapsed: Set<String> { Set(collapsedRaw.split(separator: "\n").map(String.init)) }

    private func isCollapsed(_ project: String?) -> Bool { ui.filter.isEmpty && collapsed.contains(project ?? "") }

    private func toggleCollapsed(_ project: String?) {
        var set = collapsed
        if !set.insert(project ?? "").inserted { set.remove(project ?? "") }
        collapsedRaw = set.sorted().joined(separator: "\n")
    }

    var body: some View {
        @Bindable var ui = ui
        let groups = ContainerGrouping.groups(
            rows: store.containers, query: ui.filter, runningOnly: ui.runningOnly, sort: ui.containerSort,
            cpu: { store.stats.series(for: $0).latestCPU }, memory: { store.stats.series(for: $0).latestMemory }
        )
        Group {
            if !store.hasLoaded {
                ProgressView("Loading containers…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                ContentUnavailableView(store.containers.isEmpty ? "No containers" : "Nothing matches", systemImage: "shippingbox")
            } else {
                List(selection: $ui.selectedContainerIDs) {
                    ForEach(groups, id: \.project) { group in
                        SwiftUI.Section {
                            if !isCollapsed(group.project) {
                                ForEach(group.rows) { row in
                                    ContainerRowView(row: row)
                                        .contentShape(Rectangle())
                                        .tag(row.id)
                                        .contextMenu {
                                            ContainerMenu(row: row, selectedIDs: ui.selectedContainerIDs) { ids in
                                                requestRemoval(ids, title: removalTitle(for: ids))
                                            }
                                        }
                                }
                            }
                        } header: {
                            GroupHeader(project: group.project, rows: group.rows, runningCount: group.runningCount, directory: group.directory, collapsed: isCollapsed(group.project), toggle: { toggleCollapsed(group.project) }) {
                                let groupRows = store.containers.filter { $0.project == group.project }
                                let title = "Remove all \(groupRows.count) containers \(group.project.map { "from \($0)" } ?? "that have no project")?"
                                requestRemoval(groupRows.map(\.id), title: title)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .onKeyPress(.return) {
                    guard let id = ui.selectedContainerID, ui.selectedContainerIDs.count == 1 else { return .ignored }
                    ui.show(id, tab: .logs)
                    return .handled
                }
                .onDeleteCommand {
                    let ids = Array(ui.selectedContainerIDs)
                    requestRemoval(ids, title: removalTitle(for: ids))
                }
            }
        }
        .onChange(of: ui.selectedContainerIDs) {
            if ui.selectedContainerIDs.count == 1, let id = ui.selectedContainerIDs.first {
                guard ui.selectedContainerID != id else { return }
                ui.selectedContainerID = id
                ui.detailTab = prefs.defaultDetailTab
            } else if ui.selectedContainerIDs.isEmpty {
                ui.selectedContainerID = nil
            }
        }
        .confirmationDialog(
            pendingRemoval?.title ?? "Remove containers?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button(pendingRemoval.map { $0.ids.count == 1 ? "Remove Container" : "Remove \($0.ids.count) Containers" } ?? "Remove", role: .destructive) {
                guard let pendingRemoval else { return }
                store.remove(containers: pendingRemoval.ids)
                ui.selectedContainerIDs.subtract(pendingRemoval.ids)
                if let selected = ui.selectedContainerID, pendingRemoval.ids.contains(selected) { ui.selectedContainerID = nil }
                self.pendingRemoval = nil
            }
        } message: {
            Text("Running containers are force-stopped.")
        }
    }

    private func requestRemoval(_ ids: [String], title: String) {
        guard !ids.isEmpty else { return }
        pendingRemoval = PendingContainerRemoval(ids: ids, title: title)
    }

    private func removalTitle(for ids: [String]) -> String {
        ids.count == 1 ? "Remove this container?" : "Remove \(ids.count) selected containers?"
    }

}

private struct PendingContainerRemoval {
    let ids: [String]
    let title: String
}

private struct GroupHeader: View {
    @Environment(FleetStore.self) private var store
    let project: String?
    let rows: [ContainerRow]
    let runningCount: Int
    let directory: String?
    let collapsed: Bool
    let toggle: () -> Void
    let removeAll: () -> Void

    var body: some View {
        HStack {
            Button {
                withAnimation(.snappy) { toggle() }
            } label: {
                HStack {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 12)
                    Text(project ?? "No project").font(.subheadline.weight(.semibold)).foregroundStyle(project == nil ? Color.secondary : Brand.blue)
                    Text("\(runningCount)/\(rows.count) running").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(collapsed ? "collapsed" : "expanded")
            .help(collapsed ? "Expand" : "Collapse")
            if let directory, FileManager.default.fileExists(atPath: directory) {
                Menu("Project folder", systemImage: "folder") {
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: directory)]) }
                    Button("Open in Terminal") { openInTerminal(directory) }
                    Button("Copy Path") { Clipboard.copy(directory) }
                }
                .labelStyle(.iconOnly).menuStyle(.borderlessButton).fixedSize().help(directory)
            }
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    Button("Start All") { store.perform(.start, project: project) }
                    Button("Restart All") { store.perform(.restart, project: project) }
                    Button("Stop All") { store.perform(.stop, project: project) }
                    Button("Remove All", systemImage: "trash", role: .destructive, action: removeAll)
                }
                .buttonStyle(.glass).controlSize(.small)
                .disabled(rows.contains { store.pending[$0.id] != nil })
            }
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }
}

struct ContainerMenu: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    let row: ContainerRow
    let selectedIDs: Set<String>
    let onRemove: ([String]) -> Void

    var body: some View {
        if row.isRunning {
            Button("Restart") { store.perform(.restart, on: [row.id]) }.disabled(store.pending[row.id] != nil)
            Button("Stop") { store.perform(.stop, on: [row.id]) }.disabled(store.pending[row.id] != nil)
        } else {
            Button("Start") { store.perform(.start, on: [row.id]) }.disabled(store.pending[row.id] != nil)
        }
        Button("Show Info") { ui.show(row.id) }
        Button("Show Logs") { ui.show(row.id, tab: .logs) }
        if row.isRunning { Button("Open Shell in Terminal") { openContainerShell(row, store: store) } }
        ForEach(row.ports, id: \.self) { port in
            Button("Open localhost:\(String(port)) in Browser") { NSWorkspace.shared.open(URL(string: "http://localhost:\(port)")!) }
        }
        Divider()
        Button("Copy Name") { Clipboard.copy(row.name) }
        Button("Copy ID") { Clipboard.copy(row.id) }
        Button("Copy Image") { Clipboard.copy(row.image) }
        Divider()
        Button(selectedIDs.contains(row.id) && selectedIDs.count > 1 ? "Remove \(selectedIDs.count) Selected" : "Remove", role: .destructive) {
            onRemove(selectedIDs.contains(row.id) ? Array(selectedIDs) : [row.id])
        }
    }
}

@MainActor
func openInTerminal(_ directory: String) {
    guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
    NSWorkspace.shared.open([URL(filePath: directory)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
}

@MainActor
func openContainerShell(_ row: ContainerRow, store: FleetStore) {
    let script = ShellCommand.dockerExecScript(socketPath: store.client.socketPath, containerID: row.id)
    let url = FileManager.default.temporaryDirectory.appending(path: "ccp-shell-\(row.id.prefix(12)).command")
    do {
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        NSWorkspace.shared.open(url)
    } catch {
        store.lastError = "Open shell: \(error.localizedDescription)"
    }
}

private struct ContainerRowView: View {
    @Environment(FleetStore.self) private var store
    let row: ContainerRow

    var body: some View {
        let pending = store.pending[row.id]
        HStack(spacing: 12) {
            if pending != nil {
                ProgressView().controlSize(.mini).frame(width: 9, height: 9)
            } else {
                StatusDot(color: row.display.color, label: row.display.label)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.title).lineLimit(1)
                    ForEach(row.ports, id: \.self) { PortLink(port: $0) }
                }
                Group {
                    if let pending { Text(pending.label) } else { Subtitle(row: row) }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if row.state == "running" { RowGraph(id: row.id) }
        }
        .padding(.vertical, 3)
        .opacity(pending == nil ? 1 : 0.6)
        .animation(.snappy, value: pending)
    }
}

private struct Subtitle: View {
    let row: ContainerRow

    var body: some View {
        if row.state == "running", let started = row.startedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Up \(Uptime.text(since: started, now: context.date)) · \(row.image)")
            }
        } else {
            Text(row.state == "running" ? "\(row.status) · \(row.image)" : row.status)
        }
    }
}

struct PortLink: View {
    let port: Int

    var body: some View {
        Link(destination: URL(string: "http://localhost:\(port)")!) { Text(verbatim: ":\(port)") }
            .font(.system(size: 12, design: .monospaced))
    }
}

private struct RowGraph: View {
    @Environment(FleetStore.self) private var store
    let id: String

    var body: some View {
        let series = store.stats.series(for: id)
        HStack(spacing: 8) {
            Text(Format.bytes(Int64(series.latestMemory)))
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).monospacedDigit().frame(minWidth: 56, alignment: .trailing)
            Text("\(series.latestCPU, format: .number.precision(.fractionLength(1)))%")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).monospacedDigit().frame(minWidth: 44, alignment: .trailing)
            Sparkline(values: series.cpu, maximum: max(10, series.cpu.max() ?? 10), filled: false, color: Brand.blue).frame(width: 64, height: 18)
        }
    }
}
