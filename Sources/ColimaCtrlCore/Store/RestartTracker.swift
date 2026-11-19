import Foundation

/// Spots a crash loop: a container that stops several times in a few minutes without anyone asking it to.
public struct RestartTracker: Sendable {
    public let threshold: Int
    public let window: TimeInterval
    public let cooldown: TimeInterval
    private var deaths: [String: [Date]] = [:]
    private var lastAlert: [String: Date] = [:]

    public init(threshold: Int = 3, window: TimeInterval = 300, cooldown: TimeInterval = 900) {
        self.threshold = threshold
        self.window = window
        self.cooldown = cooldown
    }

    /// The number of recent stops when this one completes a loop worth alerting about, and nil otherwise.
    public mutating func recordDeath(of id: String, at now: Date) -> Int? {
        var recent = (deaths[id] ?? []).filter { now.timeIntervalSince($0) <= window }
        recent.append(now)
        deaths[id] = recent
        guard recent.count >= threshold else { return nil }
        if let last = lastAlert[id], now.timeIntervalSince(last) < cooldown { return nil }
        lastAlert[id] = now
        return recent.count
    }
}
