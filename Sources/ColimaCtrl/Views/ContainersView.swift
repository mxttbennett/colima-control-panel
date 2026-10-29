import SwiftUI
import ColimaCtrlCore

struct ContainersView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var pendingRemoval: PendingContainerRemoval?

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
                        } header: {
                            GroupHeader(project: group.project, rows: group.rows) {
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
            }
        }
        .onKeyPress(.downArrow) { move(1, in: groups) }
        .onKeyPress(.upArrow) { move(-1, in: groups) }
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

    private struct ProjectGroup { let project: String?; let rows: [ContainerRow] }

    private func grouped() -> [ProjectGroup] {
        let query = ui.filter.lowercased()
        let rows = store.containers.filter { row in
            (!ui.runningOnly || row.isRunning)
                && (query.isEmpty || [row.name, row.service ?? "", row.project ?? "", row.image].contains { $0.lowercased().contains(query) })
        }
        let byProject = Dictionary(grouping: rows, by: \.project)
        return byProject.keys.sorted { ($0 == nil ? 1 : 0, $0 ?? "") < ($1 == nil ? 1 : 0, $1 ?? "") }.map { key in
            ProjectGroup(project: key, rows: byProject[key]!.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        }
    }

    private func move(_ step: Int, in groups: [ProjectGroup]) -> KeyPress.Result {
        let ordered = groups.flatMap(\.rows)
        guard !ordered.isEmpty else { return .ignored }
        let index = ordered.firstIndex { $0.id == ui.selectedContainerID } ?? (step > 0 ? -1 : ordered.count)
        let id = ordered[min(ordered.count - 1, max(0, index + step))].id
        ui.selectedContainerID = id
        ui.selectedContainerIDs = [id]
        return .handled
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
    let removeAll: () -> Void

    var body: some View {
        HStack {
            Text(project ?? "No project").font(.subheadline.weight(.semibold)).foregroundStyle(project == nil ? Color.secondary : Brand.blue)
            Text("\(rows.filter(\.isRunning).count)/\(rows.count) running").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if let project {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        Button("Start All") { store.perform(.start, project: project) }
                        Button("Restart All") { store.perform(.restart, project: project) }
                        Button("Stop All") { store.perform(.stop, project: project) }
                        Button("Remove All", systemImage: "trash", role: .destructive, action: removeAll)
                    }
                    .buttonStyle(.glass).controlSize(.small)
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
            Button("Restart") { store.perform(.restart, on: [row.id]) }
            Button("Stop") { store.perform(.stop, on: [row.id]) }
        } else {
            Button("Start") { store.perform(.start, on: [row.id]) }
        }
        Button("Show Logs") { ui.show(row.id, tab: .logs) }
        Divider()
        Button("Copy Name") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(row.name, forType: .string) }
        Divider()
        Button(selectedIDs.contains(row.id) && selectedIDs.count > 1 ? "Remove \(selectedIDs.count) Selected" : "Remove", role: .destructive) {
            onRemove(selectedIDs.contains(row.id) ? Array(selectedIDs) : [row.id])
        }
    }
}

private struct ContainerRowView: View {
    let row: ContainerRow

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(color: row.display.color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.title).lineLimit(1)
                    ForEach(row.ports, id: \.self) { PortLink(port: $0) }
                }
                Subtitle(row: row).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if row.state == "running" { RowGraph(id: row.id) }
        }
        .padding(.vertical, 3)
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
            Text("\(series.latestCPU, format: .number.precision(.fractionLength(1)))%")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary).monospacedDigit()
            Sparkline(values: series.cpu, maximum: max(10, series.cpu.max() ?? 10), filled: false, color: Brand.blue).frame(width: 64, height: 18)
        }
    }
}
