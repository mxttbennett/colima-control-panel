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
        let running = store.connection == .up
            ? store.containers.filter(\.isRunning).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            : []
        let headline = switch store.connection {
        case .connecting: "Connecting…"
        case .down: "Colima is stopped"
        case .up: running.isEmpty ? "Nothing running" : "\(running.count) running"
        }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let color = store.health.color { StatusDot(color: color, label: store.health.label) }
                Text(headline).zoomFont(.headline)
                if store.profile != "default" { Tag(store.profile) }
                Spacer()
            }
            VMControls()
            if store.connection == .up { containerList(running) }
            Divider()
            HStack {
                Text("This app").foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.bytes(Int64(store.selfMetrics.memory))) · \(store.selfMetrics.cpu, format: .number.precision(.fractionLength(1)))%").monospacedDigit()
            }
            .zoomFont(.caption)
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

    @ViewBuilder private func containerList(_ running: [ContainerRow]) -> some View {
        if !running.isEmpty {
            VStack(spacing: 2) {
                ForEach(running.prefix(10)) { row in
                    MenuBarRow(row: row) { show(.containers, container: row.id) }
                }
                if running.count > 10 { Text("and \(running.count - 10) more").zoomFont(.caption).foregroundStyle(.secondary) }
                if running.count > 1 {
                    Button("Stop All", systemImage: "stop.fill") { store.stopAllRunning() }
                        .buttonStyle(.liquid).controlSize(.small).padding(.top, 6)
                        .disabled(running.contains { store.pending[$0.id] != nil })
                }
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

private struct MenuBarRow: View {
    @Environment(FleetStore.self) private var store
    let row: ContainerRow
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        let pending = store.pending[row.id]
        HStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 8) {
                    if pending != nil { ProgressView().controlSize(.mini).frame(width: 8, height: 8) } else { StatusDot(color: row.display.color, size: 8, label: row.display.label) }
                    Text(row.title).lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let pending {
                Text(pending.label).zoomFont(.caption).foregroundStyle(.secondary)
            } else if hovering {
                Button("Restart", systemImage: "arrow.clockwise") { store.perform(.restart, on: [row.id]) }.help("Restart \(row.title)")
                Button("Stop", systemImage: "stop.fill") { store.perform(.stop, on: [row.id]) }.help("Stop \(row.title)")
            } else if let started = row.startedAt {
                Text(started, style: .relative).zoomFont(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .labelStyle(.iconOnly).buttonStyle(.borderless)
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
    }
}
