import Foundation

public enum RecentCommands {
    public static func bump(_ recent: [String], _ id: String, limit: Int = 8) -> [String] {
        Array(([id] + recent.filter { $0 != id }).prefix(limit))
    }

    /// Recently used items first, most recent leading, then everything else in its original order.
    public static func order<Item>(_ items: [Item], recent: [String], id: (Item) -> String) -> [Item] {
        let rank = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let used = items.filter { rank[id($0)] != nil }.sorted { (rank[id($0)] ?? 0) < (rank[id($1)] ?? 0) }
        return used + items.filter { rank[id($0)] == nil }
    }
}
