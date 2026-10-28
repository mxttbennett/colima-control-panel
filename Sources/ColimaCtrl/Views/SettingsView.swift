import AppKit
import ServiceManagement
import SwiftUI
import ColimaCtrlCore

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(ColimaSetup.self) private var setup
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @AppStorage("settingsTab") private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }.tag("general")
            ColimaTab().tabItem { Label("Colima", systemImage: "shippingbox") }.tag("colima")
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }.tag("about")
        }
        .frame(width: 540, height: 600)
        .tint(Brand.blue)
        .task { await setup.refresh() }
    }
}

private struct GeneralTab: View {
    @Environment(Preferences.self) private var prefs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            SwiftUI.Section("Appearance") {
                Toggle("Show running containers on the Dock icon", isOn: $prefs.dockBadge)
                Toggle("Show menu bar icon", isOn: $prefs.showMenuBarIcon)
                Toggle("Show running count next to the menu bar icon", isOn: $prefs.menuBarCount)
                    .disabled(!prefs.showMenuBarIcon)
            }
            SwiftUI.Section("Behavior") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Picker("Refresh graphs every", selection: $prefs.statsSeconds) {
                    ForEach([2, 3, 5, 10], id: \.self) { Text("\($0) seconds").tag($0) }
                }
                Text("Graphs only refresh while the window or menu bar popover is showing. Longer intervals use less CPU.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ColimaTab: View {
    @Environment(ColimaSetup.self) private var setup
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @State private var draft = ColimaResources(cpus: 2, memory: 4, disk: 100)
    @State private var note: String?

    private var baseline: ColimaResources { setup.current ?? setup.host.recommended }
    private var changed: Bool { draft != baseline }

    var body: some View {
        Form {
            SwiftUI.Section("Installation") {
                InstallationStatus()
                HStack {
                    if setup.configURL.path.isEmpty == false {
                        Text(setup.configURL.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Check again") { Task { await setup.refresh() } }
                    Button("Reveal config") { NSWorkspace.shared.activateFileViewerSelecting([setup.configURL]) }
                        .disabled(!FileManager.default.fileExists(atPath: setup.configURL.path))
                }
            }
            SwiftUI.Section("Resources") {
                if setup.current == nil {
                    Text("Colima has no configuration yet. Saving creates the VM and starts it.").font(.caption).foregroundStyle(.secondary)
                }
                ResourceEditor(resources: $draft, host: setup.host, minimumDisk: setup.current?.disk)
                HStack {
                    Button("Revert") { draft = baseline; note = nil }.disabled(!changed)
                    Spacer()
                    if setup.current != nil, store.connection == .up {
                        Button("Save only") { apply(restart: false) }.disabled(!changed)
                        Button("Save and restart") { apply(restart: true) }.buttonStyle(.borderedProminent).disabled(!changed)
                    } else {
                        Button(setup.current == nil ? "Create and start" : "Save") { apply(restart: false) }
                            .buttonStyle(.borderedProminent).disabled(setup.current != nil && !changed)
                    }
                }
                if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            SwiftUI.Section("Setup") {
                Button("Run setup again…") {
                    ui.showSetup = true
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
        }
        .formStyle(.grouped)
        .task(id: setup.current) { draft = baseline }
    }

    private func apply(restart: Bool) {
        let outcome = setup.save(draft, restartIfRunning: restart, engineUp: store.connection == .up, vm: store.vm)
        note = switch outcome {
        case .saved: store.connection == .up ? "Saved. It takes effect the next time Colima restarts." : "Saved. It takes effect the next time Colima starts."
        case .savedAndRestarting: "Saved. Restarting Colima now."
        case .creatingAndStarting: "Creating the VM and starting Colima."
        }
    }
}

private struct AboutTab: View {
    @Environment(Preferences.self) private var prefs
    @Environment(UIState.self) private var ui
    @Environment(\.openWindow) private var openWindow

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Colima Control Panel").font(.title2.weight(.semibold))
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("A native dashboard and menu bar companion for Colima.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/mxttbennett/colima-control-panel")!)
                Link("Colima", destination: URL(string: "https://github.com/abiosoft/colima")!)
            }
            Divider().padding(.vertical, 6)
            Button("Reset setup") {
                prefs.setupCompleted = false
                ui.showSetup = true
                openWindow(id: "main")
                NSApp.activate()
            }
            Text("Shows the first-run setup again.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}
