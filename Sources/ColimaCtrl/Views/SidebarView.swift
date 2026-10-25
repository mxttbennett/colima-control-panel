import SwiftUI
import ColimaCtrlCore

struct SidebarView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        List(Section.allCases, selection: $ui.section) { section in
            HStack {
                Label(section.title, systemImage: section.symbol)
                Spacer()
                if section == .containers, let color = store.health.color {
                    StatusDot(color: color, size: 8).help(store.health.label)
                }
                if let count = count(for: section) {
                    Text(count, format: .number).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .tag(section)
        }
        .safeAreaInset(edge: .bottom) { VMCard().padding(.horizontal, 12).padding(.bottom, 12) }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
    }

    private func count(for section: Section) -> Int? {
        switch section {
        case .containers: store.containers.count
        case .volumes: store.volumes.count
        case .images: store.images.count
        case .networks: store.networks.count
        case .system: nil
        }
    }
}

private struct VMCard: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let info = store.info {
                Text("\(info.cpus) cpu · \(Format.bytes(info.memory)) · Docker \(info.version)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            VMControls()
            if store.connection == .up { Totals() }
            Divider()
            SelfRow()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

private struct Totals: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        let totals = store.stats.totals
        let cores = Double(store.info?.cpus ?? 1)
        let memory = Double(store.info?.memory ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CPU").foregroundStyle(.secondary)
                Spacer()
                Text("\(totals.latestCPU / 100, format: .number.precision(.fractionLength(2))) of \(Int(cores)) cores").monospacedDigit()
            }
            Sparkline(values: totals.cpu, maximum: cores * 100).frame(height: 28)
            Spacer().frame(height: 4)
            HStack {
                Text("Memory").foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.bytes(Int64(totals.latestMemory))) of \(Format.bytes(Int64(memory)))").monospacedDigit()
            }
            Sparkline(values: totals.memory, maximum: memory).frame(height: 28)
        }
        .font(.caption)
    }
}

private struct SelfRow: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        let metrics = store.selfMetrics
        HStack {
            Text("Colima Ctrl").foregroundStyle(.secondary)
            Spacer()
            Text("\(Format.bytes(Int64(metrics.memory))) · \(metrics.cpu, format: .number.precision(.fractionLength(1)))%").monospacedDigit()
        }
        .font(.caption)
        .help("This app's own memory footprint and CPU use")
    }
}

struct VMControls: View {
    @Environment(FleetStore.self) private var store
    @State private var confirming: ColimaVM.Operation?

    var body: some View {
        let vm = store.vm
        Group {
            if let operation = vm.operation {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(label(for: operation)).font(.caption).foregroundStyle(.secondary)
                }
            } else if store.connection == .up {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        Button("Restart") { confirming = .restart }
                        Button("Stop") { confirming = .stop }
                    }
                    .buttonStyle(.glass).controlSize(.small)
                }
            } else if store.connection == .down {
                Button("Start Colima") { vm.run(.start) }.buttonStyle(.glassProminent).controlSize(.small)
            }
        }
        .confirmationDialog(
            confirming == .stop ? "Stop Colima?" : "Restart Colima?", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible
        ) {
            Button(confirming == .stop ? "Stop" : "Restart", role: .destructive) { if let confirming { vm.run(confirming) } }
        } message: {
            Text("Running containers stop\(confirming == .restart ? " and come back" : "").")
        }
    }

    private func label(for operation: ColimaVM.Operation) -> String {
        switch operation {
        case .start: "Starting…"
        case .stop: "Stopping…"
        case .restart: "Restarting…"
        }
    }
}
