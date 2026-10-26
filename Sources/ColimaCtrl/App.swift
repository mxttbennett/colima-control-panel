import SwiftUI
import ColimaCtrlCore

@main
struct ColimaCtrlApp: App {
    @State private var store: FleetStore
    @State private var ui = UIState()
    @State private var prefs: Preferences
    private let badge: BadgeController

    init() {
        let store = FleetStore()
        let prefs = Preferences()
        _store = State(initialValue: store)
        _prefs = State(initialValue: prefs)
        badge = BadgeController(store: store, prefs: prefs)
        store.start()
    }

    var body: some Scene {
        Window("Colima Ctrl", id: "main") {
            ContentView()
                .environment(store).environment(ui).environment(prefs)
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

        MenuBarExtra {
            MenuBarContent().environment(store).environment(ui).environment(prefs)
        } label: {
            MenuBarLabel().environment(store).environment(prefs)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(prefs)
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
