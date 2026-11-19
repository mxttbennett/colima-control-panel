import AppKit
@preconcurrency import UserNotifications
import ColimaCtrlCore

/// Posts a macOS notification when a container fails, but only while the app is in the background.
@MainActor
final class AlertNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let prefs: Preferences
    private let ui: UIState
    private let available = Bundle.main.bundlePath.hasSuffix(".app")

    init(prefs: Preferences, ui: UIState) {
        self.prefs = prefs
        self.ui = ui
        super.init()
        if available { UNUserNotificationCenter.current().delegate = self }
    }

    func post(_ alerts: [ContainerAlert]) {
        guard available, prefs.notifyOnFailures, !NSApp.isActive else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            for alert in alerts {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.body
                content.sound = .default
                content.userInfo = ["container": alert.id]
                center.add(UNNotificationRequest(identifier: "alert-\(alert.id)", content: content, trigger: nil))
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["container"] as? String else { return }
        await MainActor.run {
            ui.show(id, tab: .logs)
            NSApp.activate()
            if !NSApp.windows.contains(where: \.isVisible) { NSWorkspace.shared.open(Bundle.main.bundleURL) }
        }
    }
}
