import Foundation
import Observation

public enum ColimaInstallation: Equatable, Sendable {
    case unknown
    case missing
    case installed(path: String, version: String)
}

public enum SaveOutcome: Equatable, Sendable {
    case saved
    case savedAndRestarting
    case creatingAndStarting
}

/// What Colima looks like on this Mac: whether it is installed, which version, and the resources it is set to use.
@MainActor @Observable
public final class ColimaSetup {
    public private(set) var installation = ColimaInstallation.unknown
    public private(set) var dockerPath: String?
    public private(set) var brewPath: String?
    public private(set) var current: ColimaResources?
    public private(set) var log: [String] = []
    public private(set) var isInstalling = false
    public private(set) var error: String?

    public let host = HostSpecs.current
    public let profile: String

    public var configURL: URL { ColimaConfigFile.url(profile: profile) }
    public var isInstalled: Bool {
        if case .installed = installation { return true }
        return false
    }

    public init(profile: String? = nil) {
        self.profile = profile ?? ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? UserDefaults.standard.string(forKey: "colimaProfile") ?? "default"
    }

    public func refresh() async {
        if let path = ColimaVM.locateColima() {
            let output = await ProcessRunner.capture(path, ["version"])
            let first = output?.split(separator: "\n").first.map(String.init) ?? ""
            let version = first.split(separator: " ").last.map(String.init) ?? "unknown"
            installation = .installed(path: path, version: version)
        } else {
            installation = .missing
        }
        dockerPath = Self.find("docker")
        brewPath = Self.find("brew")
        current = (try? String(contentsOf: configURL, encoding: .utf8)).flatMap(ColimaConfigFile.parse)
    }

    public func installWithHomebrew() async {
        guard let brewPath, !isInstalling else { return }
        isInstalling = true
        log = []
        error = nil
        let box = LineBox()
        let status = await ProcessRunner.run(brewPath, ["install", "colima", "docker"]) { box.append($0) }
        log = box.joined.split(separator: "\n").map { ProcessRunner.stripANSI(String($0)) }.suffix(120).map { $0 }
        if status != 0 { error = "brew install exited with code \(status)" }
        isInstalling = false
        await refresh()
    }

    /// Saves the resources. With an existing configuration the file is edited (a backup is kept) and Colima is restarted if
    /// asked; without one, `colima start` creates and starts the VM with these values.
    public func save(_ resources: ColimaResources, restartIfRunning: Bool, engineUp: Bool, vm: ColimaVM) -> SaveOutcome {
        let url = configURL
        if let yaml = try? String(contentsOf: url, encoding: .utf8) {
            let backup = url.appendingPathExtension("bak")
            if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
            try? ColimaConfigFile.update(yaml, with: resources).write(to: url, atomically: true, encoding: .utf8)
            current = resources
            if restartIfRunning, engineUp {
                vm.run(.restart)
                return .savedAndRestarting
            }
            return .saved
        }
        vm.run(.start, extraArgs: ["--cpus", "\(resources.cpus)", "--memory", "\(resources.memory)", "--disk", "\(resources.disk)"])
        current = resources
        return .creatingAndStarting
    }

    private static func find(_ name: String) -> String? {
        ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
