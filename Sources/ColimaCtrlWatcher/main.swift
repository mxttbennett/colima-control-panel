import AppKit
import ColimaCtrlCore
import Darwin
import Foundation

@main
struct ColimaCtrlWatcher {
    @MainActor
    static func main() async {
        for key in ProcessInfo.processInfo.environment.keys {
            key.withCString { _ = unsetenv($0) }
        }
        let bundleIdentifier = "dev.mxttbennett.colima-ctrl"
        let defaults = UserDefaults(suiteName: bundleIdentifier) ?? .standard
        var profile = "default"
        var client = DockerClient(socketPath: DockerClient.defaultSocketPath(profile: profile))
        var observer = ColimaLaunchObserver()

        while true {
            let selected = defaults.string(forKey: "colimaProfile") ?? "default"
            if selected != profile {
                profile = selected
                client = DockerClient(socketPath: DockerClient.defaultSocketPath(profile: profile))
                observer = ColimaLaunchObserver()
            }
            let isRunning = await client.ping()
            if observer.shouldLaunchCCP(isRunning: isRunning), NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
                let open = Process()
                open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                open.arguments = ["-b", bundleIdentifier]
                try? open.run()
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }
}
