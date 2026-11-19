import AppKit
import Foundation

enum Format {
    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return "0 B" }
        return value.formatted(.byteCount(style: .memory, allowedUnits: [.kb, .mb, .gb, .tb], spellsOutZero: false))
    }

    static func clock(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(.dateTime.hour().minute().second())
            : date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func ago(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
