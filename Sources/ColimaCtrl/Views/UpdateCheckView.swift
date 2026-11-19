import SwiftUI
import ColimaCtrlCore

struct UpdateCheckView: View {
    let version: String

    private enum Phase {
        case idle, checking, noReleases, failed
        case found(UpdateOutcome, ReleaseInfo)
    }

    @Environment(UIState.self) private var ui
    @State private var phase = Phase.idle

    var body: some View {
        VStack(spacing: 8) {
            Button(action: check) {
                if case .checking = phase { ProgressView().controlSize(.small) } else { Text("Check for Updates") }
            }
            .buttonStyle(.liquid)
            .disabled(isChecking)
            result
            Text("Contacts github.com only when you click.").zoomFont(.caption).foregroundStyle(.secondary)
        }
        .onAppear(perform: runRequestedCheck)
        .onChange(of: ui.pendingUpdateCheck) { runRequestedCheck() }
    }

    private func runRequestedCheck() {
        guard ui.pendingUpdateCheck else { return }
        ui.pendingUpdateCheck = false
        if !isChecking { check() }
    }

    private var isChecking: Bool {
        if case .checking = phase { true } else { false }
    }

    @ViewBuilder private var result: some View {
        switch phase {
        case .idle, .checking: EmptyView()
        case .noReleases: Text("No releases are published yet.").foregroundStyle(.secondary)
        case .failed: Text("Couldn\u{2019}t reach GitHub. Check your connection and try again.").foregroundStyle(.secondary)
        case .found(let outcome, let release):
            switch outcome {
            case .upToDate: Text("You have the latest release (\(release.tag)).")
            case .development: Text("This is a development build. The latest release is \(release.tag).").foregroundStyle(.secondary)
            case .unknown: Text("Couldn\u{2019}t compare with \(release.tag).").foregroundStyle(.secondary)
            case .available(let latest):
                VStack(spacing: 6) {
                    Text("Version \(latest) is available.").fontWeight(.medium)
                    Link("View release", destination: release.url)
                    HStack(spacing: 6) {
                        Text(UpdateCheck.upgradeCommand).zoomFont(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(UpdateCheck.upgradeCommand) }.labelStyle(.iconOnly).buttonStyle(.plain).help("Copy the Homebrew upgrade command")
                    }
                }
            }
        }
    }

    private func check() {
        phase = .checking
        Task {
            do {
                if let release = try await UpdateCheck.fetchLatest() {
                    phase = .found(UpdateCheck.outcome(installed: version, latestTag: release.tag), release)
                } else {
                    phase = .noReleases
                }
            } catch {
                phase = .failed
            }
        }
    }
}

struct CheckForUpdatesButton: View {
    let ui: UIState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Check for Updates\u{2026}") {
            UserDefaults.standard.set("about", forKey: "settingsTab")
            ui.pendingUpdateCheck = true
            NSApp.activate()
            openSettings()
        }
    }
}
