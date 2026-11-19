import SwiftUI
import ColimaCtrlCore

struct ContentView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(Preferences.self) private var prefs
    @FocusState private var searchFocused: Bool
    @State private var showZoomBadge = false

    private func count(_ number: Int, _ noun: String) -> String { "\(number) \(noun)\(number == 1 ? "" : "s")" }

    private var subtitle: String {
        guard store.hasLoaded else { return "" }
        switch ui.section {
        case .containers: return "\(count(store.containers.count, "container")) · \(store.runningCount) running"
        case .volumes: return count(store.volumes.count, "volume")
        case .images: return count(store.images.count, "image")
        case .networks: return count(store.networks.count, "network")
        case .system: return ""
        case .activity: return store.activity.events.isEmpty ? "" : count(store.activity.events.count, "event")
        }
    }

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView {
            SidebarView()
        } detail: {
            PaneHost {
                if store.connection == .connecting {
                    ProgressView("Connecting to Colima…").controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.connection == .down || store.vm.isBusy && store.connection != .up {
                    DownView()
                } else {
                    Group {
                        switch ui.section {
                        case .containers: ContainersView()
                        case .volumes: VolumesView()
                        case .images: ImagesView()
                        case .networks: NetworksView()
                        case .system: SystemView()
                        case .activity: ActivityView()
                        }
                    }
                    .id(ui.section)
                    .transition(.opacity)
                    .motion(Motion.quick, value: ui.section)
                }
            }
            .navigationTitle(ui.section.title)
            .navigationSubtitle(subtitle)
            .searchable(text: $ui.filter, prompt: "Filter")
            .searchFocused($searchFocused)
            .toolbar {
                if ui.section == .containers {
                    ToolbarItem {
                        Menu("Sort", systemImage: "arrow.up.arrow.down") {
                            Picker("Sort by", selection: $ui.containerSort) {
                                ForEach(ContainerSort.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.inline).labelsHidden()
                        }
                        .help("Sort containers within each project (now: \(ui.containerSort.rawValue))")
                    }
                    ToolbarItem { Toggle("Running", systemImage: "play.circle", isOn: $ui.runningOnly).help("Show only running containers") }
                }
                if ui.section == .activity {
                    ToolbarItem { Button("Clear", systemImage: "trash") { store.clearActivity() }.help("Clear the activity log").disabled(store.activity.events.isEmpty) }
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
        .animation(.snappy, value: store.lastError)
        .confirmationDialog(
            ui.confirm?.title ?? "", isPresented: Binding(get: { ui.confirm != nil }, set: { if !$0 { ui.confirm = nil } }),
            titleVisibility: .visible
        ) {
            Button(ui.confirm?.button ?? "Confirm", role: .destructive) { ui.confirm?.action() }
        } message: {
            Text(ui.confirm?.message ?? "")
        }
        .onAppear { store.setDemand(.window, true) }
        .onDisappear { store.setDemand(.window, false) }
        .onChange(of: ui.section) { ui.filter = "" }
        .onChange(of: ui.focusFilter) { searchFocused = true }
        .onChange(of: store.containers) {
            guard let name = ui.pendingSelection, let match = store.containers.first(where: { $0.name == name }) else { return }
            ui.pendingSelection = nil
            ui.selectedContainerID = match.id
            ui.selectedContainerIDs = [match.id]
        }
        .tint(Brand.blue)
        .preferredColorScheme(prefs.appearance.colorScheme)
        .environment(\.uiZoom, ui.zoom)
        .controlSize(Zoom.controlSize(for: ui.zoom))
        .font(.system(size: 13 * ui.zoom))
        .background {
            Button("Zoom In") { ui.zoomIn() }.keyboardShortcut("=").opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            if showZoomBadge {
                Text("\(Int((ui.zoom * 100).rounded()))%").monospacedDigit().zoomFont(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onChange(of: ui.zoom) {
            withAnimation(Motion.quick) { showZoomBadge = true }
            Task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(Motion.smooth) { showZoomBadge = false }
            }
        }
        .frame(minWidth: 940, minHeight: 580)
    }

}

private struct ErrorBanner: View {
    @Environment(FleetStore.self) private var store
    @State private var hovering = false

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
            .onHover { hovering = $0 }
            .task(id: "\(message)|\(hovering)") {
                guard !hovering else { return }
                try? await Task.sleep(for: .seconds(6))
                store.lastError = nil
            }
        }
    }
}
