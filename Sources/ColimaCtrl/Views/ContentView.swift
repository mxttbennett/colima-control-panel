import SwiftUI
import ColimaCtrlCore

struct ContentView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(Preferences.self) private var prefs
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView {
            SidebarView()
        } detail: {
            PaneHost {
                if store.connection == .connecting {
                    ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.connection == .down || store.vm.isBusy && store.connection != .up {
                    DownView()
                } else {
                    switch ui.section {
                    case .containers: ContainersView()
                    case .volumes: VolumesView()
                    case .images: ImagesView()
                    case .networks: NetworksView()
                    case .system: SystemView()
                    }
                }
            }
            .navigationTitle(ui.section.title)
            .searchable(text: $ui.filter, prompt: "Filter")
            .searchFocused($searchFocused)
            .toolbar {
                if ui.section == .containers {
                    ToolbarItem { Toggle("Running", systemImage: "play.circle", isOn: $ui.runningOnly).help("Show only running containers") }
                }
                ToolbarItem { Button("Command Palette", systemImage: "command") { ui.showPalette = true }.help("Command palette (⌘K)") }
            }
            .onKeyPress("/") {
                searchFocused = true
                return .handled
            }
        }
        .sheet(isPresented: $ui.showPalette) { PaletteView() }
        .sheet(isPresented: $ui.showSetup) { SetupView() }
        .onChange(of: prefs.statsSeconds, initial: true) { store.statsInterval = .seconds(prefs.statsSeconds) }
        .overlay(alignment: .bottom) { ErrorBanner() }
        .onAppear { store.setDemand(.window, true) }
        .onDisappear { store.setDemand(.window, false) }
        .onChange(of: ui.section) { ui.filter = "" }
        .onChange(of: store.containers) {
            guard let name = ui.pendingSelection, let match = store.containers.first(where: { $0.name == name }) else { return }
            ui.pendingSelection = nil
            ui.selectedContainerID = match.id
        }
        .tint(Brand.blue)
        .frame(minWidth: 940, minHeight: 580)
    }

}

private struct ErrorBanner: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        if let message = store.lastError {
            HStack {
                Text(message).lineLimit(2)
                Button("Dismiss", systemImage: "xmark") { store.lastError = nil }.labelStyle(.iconOnly).buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassEffect(.regular.tint(.red.opacity(0.35)), in: .capsule)
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: message) {
                try? await Task.sleep(for: .seconds(6))
                store.lastError = nil
            }
        }
    }
}
