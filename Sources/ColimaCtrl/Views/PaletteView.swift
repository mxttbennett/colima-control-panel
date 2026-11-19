import SwiftUI
import ColimaCtrlCore

private struct Command: Identifiable {
    let id: String
    let title: String
    let hint: String
    let run: @MainActor () -> Void
}

struct PaletteView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(ColimaSetup.self) private var setup
    @State private var query = ""
    @AppStorage("paletteRecent") private var recentRaw = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    var body: some View {
        let results = filtered()
        let recent = Set(recentList)
        let hasRecent = results.contains { recent.contains($0.id) }
        VStack(spacing: 0) {
            TextField("Jump to a view, or act on a container", text: $query)
                .textFieldStyle(.plain).zoomFont(.title3).padding(16)
                .focused($focused)
                .onSubmit { run(results, at: selection) }
                .onChange(of: query) { selection = 0 }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, command in
                            HStack {
                                if hasRecent {
                                    Image(systemName: "clock").foregroundStyle(.secondary).frame(width: 16)
                                        .opacity(recent.contains(command.id) ? 1 : 0)
                                        .accessibilityLabel(recent.contains(command.id) ? "Recent" : "")
                                }
                                Text(command.title).lineLimit(1)
                                Spacer()
                                Text(command.hint).foregroundStyle(.secondary).zoomFont(.caption)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background {
                if index == selection { Color.clear.glassEffect(.regular.tint(Brand.blue.opacity(0.35)), in: .rect(cornerRadius: 10)) }
            }
                            .contentShape(Rectangle())
                            .onTapGesture { run(results, at: index) }
                            .id(command.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: selection) { if results.indices.contains(selection) { proxy.scrollTo(results[selection].id) } }
            }
        }
        .frame(width: 560, height: 400)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .onAppear { focused = true }
        .onKeyPress(.downArrow) { selection = min(selection + 1, max(0, results.count - 1)); return .handled }
        .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
        .onKeyPress(.escape) { ui.showPalette = false; return .handled }
        .onExitCommand { ui.showPalette = false }
        .accessibilityAddTraits(.isModal)
    }

    private func run(_ results: [Command], at index: Int) {
        guard results.indices.contains(index) else { return }
        recentRaw = RecentCommands.bump(recentList, results[index].id).joined(separator: "\n")
        ui.showPalette = false
        results[index].run()
    }

    private func confirm(_ title: String, _ message: String, _ button: String, action: @escaping @MainActor () -> Void) {
        ui.confirm = ConfirmRequest(title: title, message: message, button: button, action: action)
    }

    private var recentList: [String] { recentRaw.split(separator: "\n").map(String.init) }

    private func filtered() -> [Command] {
        let words = query.lowercased().split(separator: " ")
        let matches = commands().filter { command in words.allSatisfy { command.title.lowercased().contains($0) } }
        return Array(RecentCommands.order(matches, recent: recentList) { $0.id }.prefix(40))
    }

    private func commands() -> [Command] {
        var list = Section.allCases.map { section in
            Command(id: "go-\(section.rawValue)", title: "Go to \(section.title)", hint: "\u{2318}\(section.shortcut)") { ui.section = section }
        }
        switch store.connection {
        case .up:
            list.append(Command(id: "vm-restart", title: "Restart Colima", hint: "vm") { confirm("Restart Colima?", "Running containers stop and come back.", "Restart") { store.vm.run(.restart) } })
            list.append(Command(id: "vm-stop", title: "Stop Colima", hint: "vm") { confirm("Stop Colima?", "Running containers stop.", "Stop") { store.vm.run(.stop) } })
        case .down:
            list.append(Command(id: "vm-start", title: "Start Colima", hint: "vm") { store.vm.run(.start) })
        case .connecting:
            break
        }
        list.append(Command(id: "pull-image", title: "Pull image…", hint: "images") { ui.section = .images; ui.showPull = true })
        for kind in [PruneKind.containers, .imagesDangling, .imagesUnused, .volumes, .buildCache] {
            list.append(Command(id: "prune-\(kind.rawValue)", title: "Prune \(kind.paletteName)", hint: "prune") {
                confirm(kind.title, kind.warning, "Remove") { store.prune(kind) }
            })
        }
        for profile in ColimaProfile.available() where profile != store.profile {
            list.append(Command(id: "profile-\(profile)", title: "Switch to profile \(profile)", hint: "profile") {
                switchColimaProfile(profile, store: store, setup: setup, ui: ui)
            })
        }
        for sort in ContainerSort.allCases where sort != ui.containerSort {
            list.append(Command(id: "sort-\(sort.rawValue)", title: "Sort containers by \(sort.rawValue)", hint: "view") { ui.section = .containers; ui.containerSort = sort })
        }
        list.append(Command(id: "running-only", title: ui.runningOnly ? "Show all containers" : "Show only running containers", hint: "view") { ui.section = .containers; ui.runningOnly.toggle() })
        if !store.runningIDs.isEmpty {
            list.append(Command(id: "stop-all", title: "Stop all running containers", hint: "action") { confirm("Stop all running containers?", "\(store.runningIDs.count) containers will stop.", "Stop All") { store.stopAllRunning() } })
        }
        for row in store.containers {
            let name = row.service.map { "\($0) (\(row.name))" } ?? row.name
            list.append(Command(id: "open-\(row.id)", title: "Open \(name)", hint: "container") { ui.show(row.id) })
            list.append(Command(id: "logs-\(row.id)", title: "Logs \(name)", hint: "container") { ui.show(row.id, tab: .logs) })
            if row.isRunning {
                list.append(Command(id: "restart-\(row.id)", title: "Restart \(name)", hint: "action") { store.perform(.restart, on: [row.id]) })
                list.append(Command(id: "stop-\(row.id)", title: "Stop \(name)", hint: "action") { store.perform(.stop, on: [row.id]) })
                if row.isPaused {
                    list.append(Command(id: "resume-\(row.id)", title: "Resume \(name)", hint: "action") { store.perform(.resume, on: [row.id]) })
                } else {
                    list.append(Command(id: "pause-\(row.id)", title: "Pause \(name)", hint: "action") { store.perform(.pause, on: [row.id]) })
                }
            } else {
                list.append(Command(id: "start-\(row.id)", title: "Start \(name)", hint: "action") { store.perform(.start, on: [row.id]) })
            }
        }
        for project in Set(store.containers.compactMap(\.project)).sorted() {
            for action in [ContainerAction.start, .restart, .stop] {
                list.append(Command(id: "\(action.rawValue)-project-\(project)", title: "\(action.rawValue.capitalized) project \(project)", hint: "project") {
                    store.perform(action, project: project)
                })
            }
        }
        return list
    }
}
