import SwiftUI
import ColimaCtrlCore

struct ActivityView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var selection = Set<Int>()

    var body: some View {
        let all = store.activity.events
        let rows = all.filter(matches)
        let live = Set(store.containers.map(\.id))
        Table(rows, selection: $selection) {
            TableColumn("Time") { event in
                Text(Format.clock(event.date)).monospacedDigit().foregroundStyle(.secondary)
            }.width(min: 70, ideal: 90, max: 130)
            TableColumn("Type") { event in
                Label(event.kind.rawValue.capitalized, systemImage: Self.symbol(event.kind)).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
            }.width(min: 90, ideal: 100, max: 130)
            TableColumn("Name") { event in
                let gone = event.kind == .container && !live.contains(event.actorID)
                Text(event.subject).lineLimit(1).opacity(gone ? 0.55 : 1).help(gone ? "This container no longer exists" : "")
            }
            TableColumn("Event") { event in
                Text(event.summary).foregroundStyle(event.isFailure ? Color.red : Color.primary)
            }.width(min: 90, ideal: 130)
            TableColumn("Detail") { event in
                Text(event.detail ?? "").foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .scrollContentBackground(.hidden)
        .deselectsOnReclick()
        .zoomFont(.system(size: 13))
        .contextMenu(forSelectionType: Int.self) { ids in
            let picked = rows.filter { ids.contains($0.id) }
            if let event = picked.first, picked.count == 1 {
                if event.kind == .container, live.contains(event.actorID) {
                    Button("Show Container") { ui.show(event.actorID) }
                    Button("Show Logs") { ui.show(event.actorID, tab: .logs) }
                    Divider()
                }
                Button("Copy Name") { Clipboard.copy(event.subject) }
            } else if picked.count > 1 {
                Button("Copy \(picked.count) Names") { Clipboard.copy(picked.map(\.subject).joined(separator: "\n")) }
            }
        } primaryAction: { ids in
            if let event = rows.first(where: { ids.contains($0.id) }), event.kind == .container, live.contains(event.actorID) { ui.show(event.actorID) }
        }
        .overlay {
            if all.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "clock.arrow.circlepath", description: Text("Docker events show up here as containers start, stop and change."))
            } else if rows.isEmpty {
                NoMatches(what: "events")
            }
        }
    }

    private func matches(_ event: ActivityEvent) -> Bool {
        ui.filter.isEmpty || [event.subject, event.summary, event.kind.rawValue, event.detail ?? ""].contains { $0.localizedCaseInsensitiveContains(ui.filter) }
    }

    static func symbol(_ kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .container: "shippingbox"
        case .image: "square.stack.3d.up"
        case .volume: "cylinder"
        case .network: "point.3.connected.trianglepath.dotted"
        }
    }
}
