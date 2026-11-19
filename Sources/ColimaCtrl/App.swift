import SwiftUI
import ColimaCtrlCore

@main
struct ColimaCtrlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store: FleetStore
    @State private var ui: UIState
    @State private var prefs: Preferences
    @State private var setup = ColimaSetup()
    private let badge: BadgeController
    private let notifier: AlertNotifier

    init() {
        let store = FleetStore()
        let prefs = Preferences()
        let ui = UIState()
        let profile = ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? UserDefaults.standard.string(forKey: "colimaProfile") ?? "default"
        UserDefaults.standard.set(profile, forKey: "colimaProfile")
        ui.showSetup = !prefs.setupCompleted
        _store = State(initialValue: store)
        _prefs = State(initialValue: prefs)
        _ui = State(initialValue: ui)
        badge = BadgeController(store: store, prefs: prefs)
        let notifier = AlertNotifier(prefs: prefs, ui: ui)
        self.notifier = notifier
        store.alertHandler = { notifier.post($0) }
        AppDelegate.store = store
        AppDelegate.prefs = prefs
        AppDelegate.ui = ui
        store.start()
        if prefs.keepCCPWithColima {
            do { try ColimaWatcherService.register() }
            catch { prefs.colimaWatcherError = error.localizedDescription }
            store.vm.startIfStopped()
        }
    }

    var body: some Scene {
        Window("Colima Control Panel", id: "main") {
            ContentView()
                .environment(store).environment(ui).environment(prefs).environment(setup)
        }
        .defaultSize(width: 1120, height: 720)
        .commands {
            CommandMenu("Container") {
                let ids = ui.section == .containers ? Array(ui.selectedContainerIDs) : []
                Button("Show Info") { if let id = ids.first { ui.show(id) } }.keyboardShortcut("i").disabled(ids.count != 1)
                Button("Show Logs") { if let id = ids.first { ui.show(id, tab: .logs) } }.keyboardShortcut("l").disabled(ids.count != 1)
                Divider()
                Button("Start") { store.perform(.start, on: ids) }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(ids.isEmpty)
                Button("Restart") { store.perform(.restart, on: ids) }.keyboardShortcut("r").disabled(ids.isEmpty)
                Button("Stop") { store.perform(.stop, on: ids) }.keyboardShortcut(".").disabled(ids.isEmpty)
                let selected = store.containers.filter { ids.contains($0.id) }
                let pausable = selected.filter(\.canPause).map(\.id)
                let paused = selected.filter(\.isPaused).map(\.id)
                Button("Pause") { store.perform(.pause, on: pausable) }.disabled(pausable.isEmpty)
                Button("Resume") { store.perform(.resume, on: paused) }.disabled(paused.isEmpty)
                Divider()
                Button("Remove…") {
                    ui.confirm = ConfirmRequest(title: ids.count == 1 ? "Remove this container?" : "Remove \(ids.count) selected containers?", message: "Running containers are force-stopped.", button: ids.count == 1 ? "Remove Container" : "Remove \(ids.count) Containers") {
                        store.remove(containers: ids)
                        ui.closePane()
                    }
                }.keyboardShortcut(.delete, modifiers: .command).disabled(ids.isEmpty)
            }
            CommandGroup(after: .appInfo) { CheckForUpdatesButton(ui: ui) }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { ui.zoomIn() }.keyboardShortcut("+")
                Button("Zoom Out") { ui.zoomOut() }.keyboardShortcut("-")
                Button("Actual Size") { ui.resetZoom() }.keyboardShortcut("0")
            }
            CommandGroup(after: .textEditing) {
                Button("Find") { ui.focusFilter += 1 }.keyboardShortcut("f")
            }
            CommandMenu("Go") {
                Button("Command Palette") { ui.showPalette = true }.keyboardShortcut("k")
                Divider()
                ForEach(Section.allCases) { section in
                    Button(section.title) { ui.section = section }.keyboardShortcut(KeyEquivalent(Character("\(section.shortcut)")))
                }
            }
        }

        MenuBarExtra(isInserted: Bindable(prefs).showMenuBarIcon) {
            MenuBarContent().environment(store).environment(ui).environment(prefs)
        } label: {
            MenuBarLabel().environment(store).environment(prefs)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(prefs).environment(setup).environment(store).environment(ui)
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(FleetStore.self) private var store
    @Environment(Preferences.self) private var prefs

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(for: store.health))
            if prefs.menuBarCount, store.runningCount > 0 { Text(store.runningCount, format: .number) }
        }
    }
}
