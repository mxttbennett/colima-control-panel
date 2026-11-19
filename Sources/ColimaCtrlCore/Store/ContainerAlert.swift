import Foundation

public struct ContainerAlert: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case exited(code: Int)
        case unhealthy
        case restartLoop(count: Int)
    }

    public let id: String
    public let name: String
    public let kind: Kind

    public var title: String {
        switch kind {
        case .exited: "\(name) exited"
        case .unhealthy: "\(name) is unhealthy"
        case .restartLoop: "\(name) keeps restarting"
        }
    }

    public var body: String {
        switch kind {
        case .exited(let code): "Exit code \(code)"
        case .unhealthy: "Its health check is failing"
        case .restartLoop(let count): "It stopped \(count) times in the last few minutes"
        }
    }

    /// Exit codes 0, 130 (interrupt) and 143 (terminate) are normal shutdowns, so they stay quiet.
    private static let quietExitCodes: Set<Int> = [0, 130, 143]

    public static func diff(old: [ContainerRow], new: [ContainerRow], ignoring: Set<String>) -> [ContainerAlert] {
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return new.compactMap { row in
            guard let previous = before[row.id], !ignoring.contains(row.id) else { return nil }
            if previous.isRunning, !row.isRunning, let code = row.exitCode, !quietExitCodes.contains(code) {
                return ContainerAlert(id: row.id, name: row.name, kind: .exited(code: code))
            }
            if previous.display != .unhealthy, row.display == .unhealthy {
                return ContainerAlert(id: row.id, name: row.name, kind: .unhealthy)
            }
            return nil
        }
    }
}
