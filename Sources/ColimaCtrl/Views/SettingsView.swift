import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Toggle("Show running containers on the Dock icon", isOn: $prefs.dockBadge)
            Toggle("Show running count next to the menu bar icon", isOn: $prefs.menuBarCount)
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 200)
    }
}
