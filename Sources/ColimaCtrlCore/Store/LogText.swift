import Foundation

public enum LogLevel: Sendable, Equatable {
    case error, warning, info, debug
}

public enum LogText {
    public struct LevelMatch: Sendable {
        public let level: LogLevel
        public let range: Range<String.Index>
    }

    public struct Link: Sendable {
        public let url: URL
        public let range: Range<String.Index>
    }

    private static let upper = try! NSRegularExpression(pattern: #"\b(FATAL|CRIT|CRITICAL|PANIC|ERROR|ERR|WARNING|WARN|WRN|INFO|INF|DEBUG|DBG|TRACE|TRC)\b"#)
    private static let keyed = try! NSRegularExpression(pattern: #"(?:level=|"level":\s*")(fatal|panic|error|warning|warn|info|debug|trace)\b"#, options: .caseInsensitive)
    private static let hosting = try! NSRegularExpression(pattern: #"^(trce|dbug|info|warn|fail|crit)(?=:)"#)
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    public static func level(in text: String) -> LogLevel? { levelMatch(in: text)?.level }

    public static func levelMatch(in text: String) -> LevelMatch? {
        let full = NSRange(text.startIndex..., in: text)
        if let match = hosting.firstMatch(in: text, range: full), let range = Range(match.range(at: 1), in: text) {
            return LevelMatch(level: level(named: text[range]), range: range)
        }
        if let match = keyed.firstMatch(in: text, range: full), let range = Range(match.range(at: 1), in: text) {
            return LevelMatch(level: level(named: text[range]), range: range)
        }
        if let match = upper.firstMatch(in: text, range: full), let range = Range(match.range(at: 1), in: text) {
            return LevelMatch(level: level(named: text[range]), range: range)
        }
        return nil
    }

    public static func links(in text: String) -> [Link] {
        guard text.contains("://") || text.contains("www.") else { return [] }
        let full = NSRange(text.startIndex..., in: text)
        return (detector?.matches(in: text, range: full) ?? []).compactMap { match in
            guard let url = match.url, let range = Range(match.range, in: text) else { return nil }
            return Link(url: url, range: range)
        }
    }

    public static func matches(of query: String, in text: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        var found: [Range<String.Index>] = []
        var cursor = text.startIndex
        while cursor < text.endIndex, let range = text.range(of: query, options: .caseInsensitive, range: cursor..<text.endIndex) {
            found.append(range)
            cursor = range.upperBound
        }
        return found
    }

    private static func level(named name: Substring) -> LogLevel {
        switch name.uppercased() {
        case "FATAL", "CRIT", "CRITICAL", "PANIC", "ERROR", "ERR", "FAIL": .error
        case "WARNING", "WARN", "WRN": .warning
        case "DEBUG", "DBG", "TRACE", "TRC", "DBUG", "TRCE": .debug
        default: .info
        }
    }
}

public enum LogLevelFilter: String, CaseIterable, Sendable {
    case all, warnings, errors

    public var title: String {
        switch self {
        case .all: "All lines"
        case .warnings: "Warnings and errors"
        case .errors: "Errors only"
        }
    }

    /// Lines without a level of their own take the level of the line before them, so multi-line messages stay together.
    public func apply(_ lines: [LogLine]) -> [LogLine] {
        guard self != .all else { return lines }
        var current: LogLevel?
        return lines.filter { line in
            if let level = LogText.level(in: line.text) ?? (line.isError ? .error : nil) { current = level }
            guard let current else { return false }
            return self == .errors ? current == .error : (current == .error || current == .warning)
        }
    }
}
