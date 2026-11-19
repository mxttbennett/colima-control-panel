import SwiftUI
import ColimaCtrlCore

struct ContainersView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
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
        let groups = grouped()
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
                            GroupHeader(project: group.project, rows: group.rows, runningCount: group.runningCount, collapsed: isCollapsed(group.project), toggle: { toggleCollapsed(group.project) }) {
                                guard let project = group.project else { return }
                                let projectRows = store.containers.filter { $0.project == project }
                                let title = "Remove all \(projectRows.count) containers from \(project)?"
                                requestRemoval(projectRows.map(\.id), title: title)
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
                ui.selectedContainerID = id
                ui.detailTab = .info
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

    private func sorted(_ rows: [ContainerRow]) -> [ContainerRow] {
        let byName = { (a: ContainerRow, b: ContainerRow) in a.title.localizedStandardCompare(b.title) == .orderedAscending }
        switch ui.containerSort {
        case .name:
            return rows.sorted(by: byName)
        case .cpu:
            return rows.sorted { (store.stats.series(for: $0.id).latestCPU, $1.title) > (store.stats.series(for: $1.id).latestCPU, $0.title) }
        case .memory:
            return rows.sorted { (store.stats.series(for: $0.id).latestMemory, $1.title) > (store.stats.series(for: $1.id).latestMemory, $0.title) }
        case .uptime:
            return rows.sorted { a, b in
                switch (a.startedAt, b.startedAt) {
                case let (x?, y?): x < y
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): byName(a, b)
                }
            }
        }
    }

    private struct ProjectGroup { let project: String?; let rows: [ContainerRow]; let runningCount: Int }

    private func grouped() -> [ProjectGroup] {
        let query = ui.filter
        let rows = store.containers.filter { row in
            (!ui.runningOnly || row.isRunning)
                && (query.isEmpty || row.name.localizedCaseInsensitiveContains(query)
                    || row.service?.localizedCaseInsensitiveContains(query) == true
                    || row.project?.localizedCaseInsensitiveContains(query) == true
                    || row.image.localizedCaseInsensitiveContains(query))
        }
        let byProject = Dictionary(grouping: rows, by: \.project)
        return byProject.keys.sorted { ($0 == nil ? 1 : 0, $0 ?? "") < ($1 == nil ? 1 : 0, $1 ?? "") }.map { key in
            let rows = byProject[key]!
            return ProjectGroup(project: key, rows: sorted(rows), runningCount: rows.filter(\.isRunning).count)
        }
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
            if let project {
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
        if row.isRunning { Button("Open Shell in Terminal") { openShell() } }
        ForEach(row.ports, id: \.self) { port in
            Button("Open localhost:\(String(port)) in Browser") { NSWorkspace.shared.open(URL(string: "http://localhost:\(port)")!) }
        }
        Divider()
        Button("Copy Name") { copy(row.name) }
        Button("Copy ID") { copy(row.id) }
        Button("Copy Image") { copy(row.image) }
        Divider()
        Button(selectedIDs.contains(row.id) && selectedIDs.count > 1 ? "Remove \(selectedIDs.count) Selected" : "Remove", role: .destructive) {
            onRemove(selectedIDs.contains(row.id) ? Array(selectedIDs) : [row.id])
        }
    }
}

extension ContainerMenu {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func openShell() {
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
                Text("Up \(Format.uptime(since: started, now: context.date)) · \(row.image)")
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
