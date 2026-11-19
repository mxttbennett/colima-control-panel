import Foundation

public struct ImageReference: Sendable, Equatable {
    public let text: String

    public init(_ text: String) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool { !text.isEmpty && !text.contains(where: \.isWhitespace) }

    /// Query for `POST /images/create`: the tag is whatever follows a colon after the last slash.
    public var query: String {
        if text.contains("@") { return "fromImage=\(Self.encode(text))" }
        let lastSlash = text.lastIndex(of: "/") ?? text.startIndex
        if let colon = text[lastSlash...].lastIndex(of: ":") {
            return "fromImage=\(Self.encode(String(text[..<colon])))&tag=\(Self.encode(String(text[text.index(after: colon)...])))"
        }
        return "fromImage=\(Self.encode(text))&tag=latest"
    }

    private static func encode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Folds the newline-delimited JSON the engine streams while pulling into a status line and one overall fraction.
public struct PullProgress: Sendable, Equatable {
    private struct Layer: Sendable, Equatable {
        var current: Int64
        var total: Int64
    }

    public private(set) var status = "Starting…"
    public private(set) var error: String?
    private var layers: [String: Layer] = [:]

    public init() {}

    public var fraction: Double? {
        let total = layers.values.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        return Double(layers.values.reduce(0) { $0 + $1.current }) / Double(total)
    }

    public mutating func feed(_ line: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return }
        if let message = object["error"] as? String { error = message }
        if let text = object["status"] as? String { status = text }
        if let id = object["id"] as? String, let detail = object["progressDetail"] as? [String: Any],
           let current = (detail["current"] as? NSNumber)?.int64Value, let total = (detail["total"] as? NSNumber)?.int64Value, total > 0 {
            layers[id] = Layer(current: current, total: total)
        }
    }
}
