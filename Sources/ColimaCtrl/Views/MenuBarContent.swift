import AppKit
import SwiftUI
import ColimaCtrlCore

struct MenuBarContent: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(Preferences.self) private var prefs
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let color = store.health.color { StatusDot(color: color) }
                Text(headline).font(.headline)
                Spacer()
            }
            VMControls()
            if store.connection == .up { containerList }
            Divider()
            HStack {
                Text("This app").foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.bytes(Int64(store.selfMetrics.memory))) · \(store.selfMetrics.cpu, format: .number.precision(.fractionLength(1)))%").monospacedDigit()
            }
            .font(.caption)
            HStack {
                Button("Open Colima Control Panel") { show(.containers) }.buttonStyle(.glassProminent)
                Spacer()
                Button("Settings", systemImage: "gearshape") { NSApp.activate(); openSettings() }.labelStyle(.iconOnly).buttonStyle(.glass)
                Button("Quit", systemImage: "power") { NSApplication.shared.terminate(nil) }.labelStyle(.iconOnly).buttonStyle(.glass)
            }
        }
        .padding(16)
        .tint(Brand.blue)
        .frame(width: 340)
        .onChange(of: prefs.statsSeconds, initial: true) { store.statsInterval = .seconds(prefs.statsSeconds) }
        .onAppear { store.setDemand(.popover, true) }
        .onDisappear { store.setDemand(.popover, false) }
    }

    private var headline: String {
        switch store.connection {
        case .connecting: "Connecting…"
        case .down: "Colima is stopped"
        case .up: store.runningCount == 0 ? "Nothing running" : "\(store.runningCount) running"
        }
    }

    private var running: [ContainerRow] { store.containers.filter(\.isRunning).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }

    @ViewBuilder private var containerList: some View {
        if !running.isEmpty {
            VStack(spacing: 2) {
                ForEach(running.prefix(10)) { row in
                    Button { show(.containers, container: row.id) } label: {
                        HStack(spacing: 8) {
                            StatusDot(color: row.display.color, size: 8)
                            Text(row.title).lineLimit(1)
                            Spacer()
                            if let started = row.startedAt {
                                Text(started, style: .relative).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .padding(.vertical, 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if running.count > 10 { Text("and \(running.count - 10) more").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func show(_ section: Section, container: String? = nil) {
        ui.section = section
        if let container { ui.show(container) }
        openWindow(id: "main")
        NSApp.activate()
    }
}
