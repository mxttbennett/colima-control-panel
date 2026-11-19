import Foundation

public struct ActivityEvent: Identifiable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case container, image, volume, network }

    public let id: Int
    public let date: Date
    public let kind: Kind
    public let actorID: String
    public let subject: String
    public internal(set) var summary: String
    public let detail: String?
    public internal(set) var isFailure: Bool
    let exitCode: Int?
}

/// Recent Docker events, newest first, with the chatty ones (exec, attach, mounts, connects) left out.
public struct ActivityLog: Sendable {
    public static let capacity = 500
    private static let foldWindow: TimeInterval = 5

    public private(set) var events: [ActivityEvent] = []
    private var nextID = 0

    public init() {}

    public mutating func clear() { events = [] }

    mutating func record(_ api: APIEvent, now: Date = .now) {
        guard let kind = ActivityEvent.Kind(rawValue: api.type) else { return }
        let action = api.action.split(separator: ":").first.map(String.init) ?? api.action
        let attributes = api.actor?.attributes ?? [:]
        let actorID = api.actor?.id ?? ""
        guard let (summary, failure) = Self.describe(kind, action: action, rawAction: api.action, attributes: attributes) else { return }
        let exitCode = action == "die" ? attributes["exitCode"].flatMap(Int.init) ?? 0 : nil

        let date = api.timeNano.map { Date(timeIntervalSince1970: Double($0) / 1e9) } ?? api.time.map { Date(timeIntervalSince1970: Double($0)) } ?? now
        let subject = attributes["name"] ?? Self.shortID(actorID)

        if kind == .container, let index = events.firstIndex(where: { $0.kind == .container && $0.actorID == actorID }), date.timeIntervalSince(events[index].date) < Self.foldWindow {
            let previous = events[index]
            if action == "stop", let code = previous.exitCode, Self.endsAStop(code) {
                events[index].summary = summary
                events[index].isFailure = false
                return
            }
            if let code = exitCode, previous.summary == "stopped", Self.endsAStop(code) { return }
        }

        let detail = kind == .container ? (attributes["image"] ?? attributes["oldName"]) : nil
        events.insert(ActivityEvent(id: nextID, date: date, kind: kind, actorID: actorID, subject: subject, summary: summary, detail: detail, isFailure: failure, exitCode: exitCode), at: 0)
        nextID += 1
        if events.count > Self.capacity { events.removeLast(events.count - Self.capacity) }
    }

    /// A stopped container exits 0, 143 (terminated) or 137 (killed after the stop timeout); those exits are the stop itself.
    private static func endsAStop(_ code: Int) -> Bool { ContainerAlert.quietExitCodes.contains(code) || code == 137 }

    private static func describe(_ kind: ActivityEvent.Kind, action: String, rawAction: String, attributes: [String: String]) -> (String, Bool)? {
        switch (kind, action) {
        case (.container, "exec_create"), (.container, "exec_start"), (.container, "exec_die"), (.container, "exec_detach"),
             (.container, "attach"), (.container, "resize"), (.container, "kill"), (.container, "top"), (.container, "copy"),
             (.container, "extract-to-dir"), (.container, "archive-path"), (.container, "export"), (.container, "commit"),
             (.volume, "mount"), (.volume, "unmount"), (.network, "connect"), (.network, "disconnect"):
            return nil
        case (.container, "die"):
            let code = attributes["exitCode"].flatMap(Int.init) ?? 0
            return ("exited (\(code))", !ContainerAlert.quietExitCodes.contains(code))
        case (.container, "health_status"):
            let state = rawAction.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            return (state == "starting" ? "health check starting" : state, state == "unhealthy")
        case (.container, "oom"): return ("ran out of memory", true)
        case (_, "start"): return ("started", false)
        case (_, "stop"): return ("stopped", false)
        case (_, "restart"): return ("restarted", false)
        case (_, "pause"): return ("paused", false)
        case (_, "unpause"): return ("resumed", false)
        case (_, "create"): return ("created", false)
        case (.image, "delete"): return ("deleted", false)
        case (_, "destroy"): return ("removed", false)
        case (_, "rename"): return ("renamed", false)
        case (_, "pull"): return ("pulled", false)
        case (_, "push"): return ("pushed", false)
        case (_, "tag"): return ("tagged", false)
        case (_, "untag"): return ("untagged", false)
        default: return (action, false)
        }
    }

    private static func shortID(_ id: String) -> String {
        String((id.split(separator: ":").last ?? Substring(id)).prefix(12))
    }
}
