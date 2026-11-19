import Foundation

public enum ContainerSort: String, CaseIterable, Identifiable, Sendable {
    case name = "Name", cpu = "CPU", memory = "Memory", uptime = "Uptime"
    public var id: String { rawValue }
}

public struct ProjectGroup: Equatable, Sendable {
    public let project: String?
    public let rows: [ContainerRow]
    public var runningCount: Int { rows.filter(\.isRunning).count }
    /// The folder Compose ran from, read from the containers' labels.
    public var directory: String? { rows.lazy.compactMap(\.projectDirectory).first }
}

public enum ContainerGrouping {
    public static func matches(_ row: ContainerRow, query: String) -> Bool {
        query.isEmpty
            || row.name.localizedCaseInsensitiveContains(query)
            || row.service?.localizedCaseInsensitiveContains(query) == true
            || row.project?.localizedCaseInsensitiveContains(query) == true
            || row.image.localizedCaseInsensitiveContains(query)
    }

    /// Compose projects in name order with loose containers last; rows inside each project follow `sort`.
    public static func groups(
        rows: [ContainerRow], query: String, runningOnly: Bool, sort: ContainerSort,
        cpu: (String) -> Double = { _ in 0 }, memory: (String) -> Double = { _ in 0 }
    ) -> [ProjectGroup] {
        let visible = rows.filter { (!runningOnly || $0.isRunning) && matches($0, query: query) }
        let inProjects = Dictionary(grouping: visible.filter { $0.project != nil }, by: { $0.project ?? "" })
        var groups = inProjects.keys.sorted().map { name in
            ProjectGroup(project: name, rows: sorted(inProjects[name] ?? [], by: sort, cpu: cpu, memory: memory))
        }
        let loose = visible.filter { $0.project == nil }
        if !loose.isEmpty { groups.append(ProjectGroup(project: nil, rows: sorted(loose, by: sort, cpu: cpu, memory: memory))) }
        return groups
    }

    static func sorted(_ rows: [ContainerRow], by sort: ContainerSort, cpu: (String) -> Double, memory: (String) -> Double) -> [ContainerRow] {
        let byName = { (a: ContainerRow, b: ContainerRow) in a.title.localizedStandardCompare(b.title) == .orderedAscending }
        func descending(by value: (String) -> Double) -> [ContainerRow] {
            rows.sorted { a, b in value(a.id) == value(b.id) ? byName(a, b) : value(a.id) > value(b.id) }
        }
        switch sort {
        case .name: return rows.sorted(by: byName)
        case .cpu: return descending(by: cpu)
        case .memory: return descending(by: memory)
        case .uptime:
            return rows.sorted { a, b in
                switch (a.startedAt, b.startedAt) {
                case let (x?, y?): x == y ? byName(a, b) : x < y
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): byName(a, b)
                }
            }
        }
    }
}

public enum Uptime {
    public static func text(since start: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        switch seconds {
        case ..<60: return "\(seconds)s"
        case ..<3600: return "\(seconds / 60)m \(seconds % 60)s"
        case ..<86400: return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        default: return "\(seconds / 86400)d \(seconds % 86400 / 3600)h"
        }
    }
}

extension ContainerInspect {
    public static func exitDescription(code: Int, oomKilled: Bool) -> String {
        if code == 0 { return "0 (success)" }
        if oomKilled { return "\(code) (out of memory)" }
        if code > 128 { return "\(code) (signal \(code - 128))" }
        return "\(code)"
    }
}
