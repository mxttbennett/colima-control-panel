import SwiftUI
import ColimaCtrlCore

private struct NetworkLine: Identifiable {
    let network: NetworkRow
    let containers: Int
    var id: String { network.id }
    var name: String { network.name }
    var driver: String { "\(network.driver) · \(network.scope)" }
    var subnet: String { network.subnetKey }
}

struct NetworksView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var sortOrder = [KeyPathComparator(\NetworkLine.name)]
    @State private var removals: [NetworkRow] = []

    var body: some View {
        let containerCounts = store.containers.reduce(into: [String: Int]()) { counts, row in row.networks.forEach { counts[$0, default: 0] += 1 } }
        let rows = store.networks
            .filter { ui.filter.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.filter) || ($0.subnet ?? "").contains(ui.filter) }
            .map { NetworkLine(network: $0, containers: containerCounts[$0.name] ?? 0) }
            .sorted(using: sortOrder)
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedNetworkIDs, sortOrder: $sortOrder) {
            TableColumn("Network", value: \.name) { line in
                HStack(spacing: 6) {
                    Text(line.network.name)
                    if line.network.isBuiltIn { Tag("built-in") }
                    if line.network.isInternal { Tag("internal") }
                }
            }
            TableColumn("Driver", value: \.driver) { Text($0.driver).foregroundStyle(.secondary) }.width(130)
            TableColumn("Subnet", value: \.subnet) { Text($0.subnet).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary) }.width(150)
            TableColumn("Containers", value: \.containers) { line in
                Text(line.containers, format: .number).monospacedDigit()
            }.width(90)
        }
        .scrollContentBackground(.hidden)
        .deselectsOnReclick()
        .contextMenu(forSelectionType: String.self) { ids in
            let picked = rows.filter { ids.contains($0.id) }
            if let line = picked.first, picked.count == 1 {
                Button("Copy Name") { Clipboard.copy(line.name) }
                Button("Copy ID") { Clipboard.copy(line.id) }
                if let subnet = line.network.subnet { Button("Copy Subnet") { Clipboard.copy(subnet) } }
                if !line.network.isBuiltIn {
                    Divider()
                    Button("Remove…", role: .destructive) { removals = [line.network] }
                }
            } else if picked.count > 1 {
                Button("Copy \(picked.count) Names") { Clipboard.copy(picked.map(\.name).joined(separator: "\n")) }
                let custom = picked.filter { !$0.network.isBuiltIn }
                if !custom.isEmpty {
                    Divider()
                    Button("Remove \(custom.count) Networks…", role: .destructive) { removals = custom.map(\.network) }
                }
            }
        }
        .confirmationDialog(removals.count == 1 ? "Remove network \(removals[0].name)?" : "Remove \(removals.count) networks?", isPresented: Binding(get: { !removals.isEmpty }, set: { if !$0 { removals = [] } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) { store.remove(networks: removals.map(\.id)) }
        } message: {
            Text("Containers using them must be stopped first.")
        }
        .overlay {
            if !store.hasLoaded { ProgressView("Loading networks…") } else if rows.isEmpty { ContentUnavailableView("No networks", systemImage: "point.3.connected.trianglepath.dotted") }
        }
    }
}
