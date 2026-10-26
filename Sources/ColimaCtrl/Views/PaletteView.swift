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
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    var body: some View {
        let results = filtered()
        VStack(spacing: 0) {
            TextField("Jump to a view, or act on a container", text: $query)
                .textFieldStyle(.plain).font(.title3).padding(16)
                .focused($focused)
                .onSubmit { run(results, at: selection) }
                .onChange(of: query) { selection = 0 }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, command in
                            HStack {
                                Text(command.title).lineLimit(1)
                                Spacer()
                                Text(command.hint).foregroundStyle(.secondary).font(.caption)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(index == selection ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 8))
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
        .onAppear { focused = true }
        .onKeyPress(.downArrow) { selection = min(selection + 1, max(0, results.count - 1)); return .handled }
        .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
    }

    private func run(_ results: [Command], at index: Int) {
        guard results.indices.contains(index) else { return }
        dismiss()
        results[index].run()
    }

    private func filtered() -> [Command] {
        let words = query.lowercased().split(separator: " ")
        return Array(commands().filter { command in words.allSatisfy { command.title.lowercased().contains($0) } }.prefix(40))
    }

    private func commands() -> [Command] {
        var list = Section.allCases.map { section in
            Command(id: "go-\(section.rawValue)", title: "Go to \(section.title)", hint: "view") { ui.section = section }
        }
        switch store.connection {
        case .up:
            list.append(Command(id: "vm-restart", title: "Restart Colima", hint: "vm") { store.vm.run(.restart) })
            list.append(Command(id: "vm-stop", title: "Stop Colima", hint: "vm") { store.vm.run(.stop) })
        case .down:
            list.append(Command(id: "vm-start", title: "Start Colima", hint: "vm") { store.vm.run(.start) })
        case .connecting:
            break
        }
        for row in store.containers {
            let name = row.service.map { "\($0) (\(row.name))" } ?? row.name
            list.append(Command(id: "open-\(row.id)", title: "Open \(name)", hint: "container") { ui.show(row.id) })
            list.append(Command(id: "logs-\(row.id)", title: "Logs \(name)", hint: "container") { ui.show(row.id, tab: .logs) })
            if row.isRunning {
                list.append(Command(id: "restart-\(row.id)", title: "Restart \(name)", hint: "action") { store.perform(.restart, on: [row.id]) })
                list.append(Command(id: "stop-\(row.id)", title: "Stop \(name)", hint: "action") { store.perform(.stop, on: [row.id]) })
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
