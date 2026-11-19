import Foundation

public enum ColimaProfile {
    /// The profile from `COLIMA_PROFILE`, then the saved choice, then "default".
    public static func current() -> String {
        ProcessInfo.processInfo.environment["COLIMA_PROFILE"] ?? UserDefaults.standard.string(forKey: "colimaProfile") ?? "default"
    }

    public static var home: URL { FileManager.default.homeDirectoryForCurrentUser.appending(path: ".colima") }

    /// Colima keeps each profile in its own folder, and prefixes its internal folders (`_lima`, `_store`) with an underscore.
    public static func available(in root: URL = home) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let names = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix("_") && !$0.hasPrefix(".") }
        let others = Set(names).subtracting(["default"]).sorted()
        return ["default"] + others
    }
}
