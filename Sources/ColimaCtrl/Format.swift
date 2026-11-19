import Foundation

enum Format {
    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return "0 B" }
        return value.formatted(.byteCount(style: .memory, allowedUnits: [.kb, .mb, .gb, .tb], spellsOutZero: false))
    }

    static func ago(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
