import Foundation

/// How much of a container's log history to load.
public enum LogRange: String, CaseIterable, Identifiable, Sendable {
    case recent, fiveMinutes, hour, day, all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .recent: "Last 300 lines"
        case .fiveMinutes: "Last 5 minutes"
        case .hour: "Last hour"
        case .day: "Last 24 hours"
        case .all: "Everything"
        }
    }

    private var window: TimeInterval? {
        switch self {
        case .recent, .all: nil
        case .fiveMinutes: 300
        case .hour: 3600
        case .day: 86400
        }
    }

    /// Query-string tail for the Docker logs endpoint; `capacity` caps how many lines a range or "everything" pulls in.
    func query(now: Date, capacity: Int) -> String {
        switch self {
        case .recent: return "tail=300"
        case .all: return "tail=\(capacity)"
        default: return "since=\(Int(now.timeIntervalSince1970 - (window ?? 0)))&tail=\(capacity)"
        }
    }
}
