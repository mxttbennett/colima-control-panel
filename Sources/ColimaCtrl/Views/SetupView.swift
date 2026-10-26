import SwiftUI
import ColimaCtrlCore

/// First-run setup: check Colima is installed, then confirm or choose the resources it may use.
struct SetupView: View {
    @Environment(ColimaSetup.self) private var setup
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(Preferences.self) private var prefs

    private enum Step: Int { case check, resources, finish }

    @State private var step = Step.check
    @State private var draft = ColimaResources(cpus: 2, memory: 4, disk: 100)
    @State private var changing = false
    @State private var seeded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            Group {
                switch step {
                case .check: checkStep
                case .resources: resourcesStep
                case .finish: finishStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .padding(24)
        .frame(width: 560, height: 560)
        .task {
            await setup.refresh()
            if !seeded {
                draft = setup.current ?? setup.host.recommended
                seeded = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set up Colima").font(.title2.weight(.semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index <= step.rawValue ? Brand.blue : Color.secondary.opacity(0.3)).frame(width: 22, height: 5)
                }
            }
        }
    }

    private var subtitle: String {
        switch step {
        case .check: "Step 1 of 3 · Check the install"
        case .resources: "Step 2 of 3 · What Colima may use"
        case .finish: "Step 3 of 3 · Confirm"
        }
    }

    // MARK: Step 1

    private var checkStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstallationStatus()
            switch setup.installation {
            case .installed:
                Label("Colima is installed. Next you'll pick what it may use.", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            case .missing:
                missingHelp
            case .unknown:
                ProgressView().controlSize(.small)
            }
        }
    }

    private var missingHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colima isn't installed yet.").font(.headline)
            Text("It runs containers in a small Linux VM. Install it with Homebrew:").foregroundStyle(.secondary)
            HStack {
                Text("brew install colima docker").font(.system(size: 13, design: .monospaced))
                CopyButton(text: "brew install colima docker")
                Spacer()
                if setup.brewPath != nil {
                    Button(setup.isInstalling ? "Installing…" : "Install with Homebrew") { Task { await setup.installWithHomebrew() } }
                        .buttonStyle(.borderedProminent).disabled(setup.isInstalling)
                }
            }
            .padding(10).background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
            if setup.brewPath == nil {
                Text("Homebrew isn't installed either. Get it from brew.sh, then run the command above.").font(.caption).foregroundStyle(.secondary)
            }
            if setup.isInstalling { ProgressView().controlSize(.small) }
            if let error = setup.error { Text(error).foregroundStyle(.red) }
            if !setup.log.isEmpty {
                ScrollView {
                    Text(setup.log.joined(separator: "\n")).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
        }
    }

    // MARK: Step 2

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = setup.current {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Colima is already configured", systemImage: "gearshape.2").font(.headline)
                    Text("It currently uses \(current.cpus) CPU cores, \(current.memory) GiB of memory and a \(current.disk) GiB disk.").foregroundStyle(.secondary)
                }
                Picker("", selection: $changing) {
                    Text("Keep these").tag(false)
                    Text("Change them").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                if changing { ResourceEditor(resources: $draft, host: setup.host, minimumDisk: current.disk) }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("No configuration yet", systemImage: "sparkles").font(.headline)
                    Text("This Mac has \(setup.host.cores) cores and \(setup.host.memoryGiB) GiB of memory. These suggestions leave plenty for macOS. Adjust them if you like.").foregroundStyle(.secondary)
                }
                ResourceEditor(resources: $draft, host: setup.host, minimumDisk: nil)
            }
        }
    }

    // MARK: Step 3

    private var effective: ColimaResources { setup.current != nil && !changing ? setup.current! : draft }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Colima will use").font(.headline)
            HStack(spacing: 12) {
                summary("\(effective.cpus)", "CPU cores")
                summary("\(effective.memory) GiB", "memory")
                summary("\(effective.disk) GiB", "disk")
            }
            Text(outcomeText).foregroundStyle(.secondary)
            Divider()
            @Bindable var prefs = prefs
            Toggle("Show the number of running containers on the Dock icon", isOn: $prefs.dockBadge)
            Text("Optional. You can change it later in Settings.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var unchanged: Bool { setup.current != nil && (!changing || draft == setup.current) }

    private var outcomeText: String {
        if unchanged { return "Nothing to change. You can adjust this any time in Settings." }
        if setup.current == nil { return "Colima has no VM yet, so it will be created and started with these values." }
        if store.connection == .up { return "Colima is running. Saving updates its configuration, and a restart applies it. Running containers stop and come back." }
        return "Colima is stopped. The new values apply the next time it starts."
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Skip for now") { finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            if step != .check { Button("Back") { step = Step(rawValue: step.rawValue - 1)! } }
            switch step {
            case .check:
                Button("Check again") { Task { await setup.refresh() } }
                Button("Continue") { step = .resources }.buttonStyle(.borderedProminent).disabled(!setup.isInstalled)
            case .resources:
                Button("Continue") { step = .finish }.buttonStyle(.borderedProminent)
            case .finish:
                if unchanged {
                    Button("Done") { finish() }.buttonStyle(.borderedProminent)
                } else if setup.current != nil, store.connection == .up {
                    Button("Save only") { _ = setup.save(draft, restartIfRunning: false, engineUp: true, vm: store.vm); finish() }
                    Button("Save and restart") { _ = setup.save(draft, restartIfRunning: true, engineUp: true, vm: store.vm); finish() }.buttonStyle(.borderedProminent)
                } else if setup.current != nil {
                    Button("Save") { _ = setup.save(draft, restartIfRunning: false, engineUp: false, vm: store.vm); finish() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Create and start Colima") { _ = setup.save(draft, restartIfRunning: false, engineUp: false, vm: store.vm); finish() }.buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func finish() {
        prefs.setupCompleted = true
        ui.showSetup = false
    }
}
