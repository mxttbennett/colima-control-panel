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
        AppDelegate.store = store
        AppDelegate.vm = store.vm
        AppDelegate.prefs = prefs
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
            CommandMenu("Go") {
                Button("Command Palette") { ui.showPalette = true }.keyboardShortcut("k")
                Divider()
                ForEach(Array(Section.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) { ui.section = section }.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
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
