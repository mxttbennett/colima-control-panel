import AppKit
import ColimaCtrlCore

/// Adds "Stop All Running Containers" to the menu you get by right-clicking the Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var store: FleetStore?

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Stop All Running Containers", action: #selector(stopAll), keyEquivalent: "")
        item.target = self
        item.isEnabled = (Self.store?.runningIDs.isEmpty ?? true) == false
        menu.addItem(item)
        return menu
    }

    @objc private func stopAll() {
        guard let store = Self.store else { return }
        let count = store.runningIDs.count
        guard count > 0 else { return }
        let alert = NSAlert()
        alert.messageText = count == 1 ? "Stop the running container?" : "Stop all \(count) running containers?"
        alert.informativeText = "They shut down gracefully. Images, volumes and data are kept."
        alert.addButton(withTitle: "Stop All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.stopAllRunning() }
    }
}
