import Foundation

/// What the Dock menu lists, kept apart from AppKit so it can be tested.
public enum DockMenu {
    public struct Project: Equatable, Sendable {
        public let name: String
        public let running: Int
        public let total: Int
    }

    public static func runningContainers(_ rows: [ContainerRow], limit: Int = 10) -> [ContainerRow] {
        Array(rows.filter(\.isRunning).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }.prefix(limit))
    }

    public static func projects(_ rows: [ContainerRow]) -> [Project] {
        let grouped = Dictionary(grouping: rows.filter { $0.project != nil }, by: { $0.project ?? "" })
        return grouped.keys.sorted().map { name in
            let members = grouped[name] ?? []
            return Project(name: name, running: members.filter(\.isRunning).count, total: members.count)
        }
    }
}
