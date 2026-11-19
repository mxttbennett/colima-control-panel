import AppKit
import ColimaCtrlCore

/// Adds the running containers, per-project actions and "Stop All Running Containers" to the menu you get by right-clicking the Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var store: FleetStore?
    static var prefs: Preferences?
    static weak var ui: UIState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.prefs?.keepCCPWithColima == true, let vm = Self.store?.vm else { return .terminateNow }
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
        guard let store = Self.store else { return menu }

        let running = DockMenu.runningContainers(store.containers)
        for row in running {
            let item = NSMenuItem(title: row.title, action: #selector(openContainer(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = row.id
            item.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Running")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [row.display == .unhealthy ? .systemRed : .systemGreen]))
            menu.addItem(item)
        }

        let projects = DockMenu.projects(store.containers)
        if !projects.isEmpty {
            if !running.isEmpty { menu.addItem(.separator()) }
            for project in projects {
                let submenu = NSMenu()
                for (title, action, enabled) in [
                    ("Start All", ContainerAction.start, project.running < project.total),
                    ("Restart All", .restart, project.running > 0),
                    ("Stop All", .stop, project.running > 0),
                ] {
                    let item = NSMenuItem(title: title, action: #selector(projectAction(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = ProjectCommand(action: action, project: project.name)
                    item.isEnabled = enabled
                    submenu.addItem(item)
                }
                let parent = NSMenuItem(title: "\(project.name) (\(project.running)/\(project.total))", action: nil, keyEquivalent: "")
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let item = NSMenuItem(title: "Stop All Running Containers", action: #selector(stopAll), keyEquivalent: "")
        item.target = self
        item.isEnabled = !store.runningIDs.isEmpty
        menu.addItem(item)
        return menu
    }

    @objc private func openContainer(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Self.ui?.show(id)
        NSApp.activate()
        if !NSApp.windows.contains(where: \.isVisible) { NSWorkspace.shared.open(Bundle.main.bundleURL) }
    }

    @objc private func projectAction(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? ProjectCommand else { return }
        Self.store?.perform(command.action, project: command.project)
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

private final class ProjectCommand: NSObject {
    let action: ContainerAction
    let project: String

    init(action: ContainerAction, project: String) {
        self.action = action
        self.project = project
    }
}
