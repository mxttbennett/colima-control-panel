import SwiftUI
import ColimaCtrlCore

/// Whether Colima, Docker and Homebrew are on this Mac, and which Colima version.
struct InstallationStatus: View {
    @Environment(ColimaSetup.self) private var setup
    @Environment(FleetStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            line("Colima", status: colimaStatus, ok: setup.isInstalled)
            if case .installed(let path, let version) = setup.installation {
                detail("Version", version)
                detail("Location", path)
            }
            line("Docker CLI", status: setup.dockerPath == nil ? "Not found" : "Installed", ok: setup.dockerPath != nil)
            line("Homebrew", status: setup.brewPath == nil ? "Not found" : "Installed", ok: setup.brewPath != nil)
            detail("Profile", setup.profile)
            detail("Engine", engine)
        }
    }

    private var colimaStatus: String {
        switch setup.installation {
        case .unknown: "Checking…"
        case .missing: "Not installed"
        case .installed: "Installed"
        }
    }

    private var engine: String {
        switch store.connection {
        case .connecting: "Connecting…"
        case .up: "Running"
        case .down: "Stopped"
        }
    }

    private func line(_ title: String, status: String, ok: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(status, systemImage: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? Color.green : Color.secondary)
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).multilineTextAlignment(.trailing)
        }
    }
}
