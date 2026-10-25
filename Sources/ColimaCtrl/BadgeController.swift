import AppKit
import Observation
import ColimaCtrlCore

/// Keeps the Dock badge in step with the running count, without polling.
@MainActor
final class BadgeController {
    private var task: Task<Void, Never>?

    init(store: FleetStore, prefs: Preferences) {
        task = Task {
            let changes = Observations { prefs.dockBadge ? store.runningCount : 0 }
            for await count in changes {
                NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
            }
        }
    }

    deinit { task?.cancel() }
}
