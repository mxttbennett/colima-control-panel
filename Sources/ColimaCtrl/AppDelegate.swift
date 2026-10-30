import AppKit
import ColimaCtrlCore

/// Adds "Stop All Running Containers" to the menu you get by right-clicking the Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var store: FleetStore?
    static var vm: ColimaVM?
    static var prefs: Preferences?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.prefs?.keepCCPWithColima == true, let vm = Self.vm else { return .terminateNow }
        Task { @MainActor in
            if await vm.stopIfRunning() {
                sender.reply(toApplicationShouldTerminate: true)
            } else {
                let alert = NSAlert()
                alert.messageText = "Colima couldn't stop"
                alert.informativeText = vm.error ?? "Colima returned an error while stopping."
                alert.addButton(withTitle: "Quit Anyway")
                alert.addButton(withTitle: "Cancel")
                sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertFirstButtonReturn)
            }
        }
        return .terminateLater
    }

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
