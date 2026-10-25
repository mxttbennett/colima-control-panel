import AppKit
import ColimaCtrlCore

@MainActor
enum MenuBarIcon {
    /// A box with cables springing out, drawn in the menu bar's label color, with a colored status dot.
    static func image(for health: FleetHealth) -> NSImage {
        let size = NSSize(width: 21, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.set()
            let box = NSBezierPath()
            box.lineWidth = 1.4
            box.lineJoinStyle = .round
            box.lineCapStyle = .round
            box.move(to: NSPoint(x: 3, y: 7)); box.line(to: NSPoint(x: 8, y: 4.5)); box.line(to: NSPoint(x: 13, y: 7))
            box.move(to: NSPoint(x: 3, y: 7)); box.line(to: NSPoint(x: 3, y: 2.5)); box.line(to: NSPoint(x: 8, y: 0.5)); box.line(to: NSPoint(x: 13, y: 2.5)); box.line(to: NSPoint(x: 13, y: 7))
            box.move(to: NSPoint(x: 8, y: 4.5)); box.line(to: NSPoint(x: 8, y: 0.5))
            box.move(to: NSPoint(x: 3, y: 7)); box.line(to: NSPoint(x: 1.2, y: 9.2))
            box.move(to: NSPoint(x: 13, y: 7)); box.line(to: NSPoint(x: 14.8, y: 9.2))
            box.stroke()

            let wires = NSBezierPath()
            wires.lineWidth = 1.2
            wires.lineCapStyle = .round
            let fan: [(start: NSPoint, c1: NSPoint, c2: NSPoint, end: NSPoint)] = [
                (NSPoint(x: 6, y: 5.5), NSPoint(x: 3.5, y: 6), NSPoint(x: 2, y: 8), NSPoint(x: 1.5, y: 10.5)),
                (NSPoint(x: 7, y: 5.5), NSPoint(x: 5, y: 8), NSPoint(x: 3, y: 10), NSPoint(x: 3.8, y: 15)),
                (NSPoint(x: 8, y: 5.5), NSPoint(x: 6.5, y: 9), NSPoint(x: 10, y: 12), NSPoint(x: 8, y: 16.8)),
                (NSPoint(x: 9, y: 5.5), NSPoint(x: 11, y: 8), NSPoint(x: 13, y: 10), NSPoint(x: 12.2, y: 15)),
                (NSPoint(x: 10, y: 5.5), NSPoint(x: 12.5, y: 6), NSPoint(x: 14, y: 8), NSPoint(x: 14.5, y: 10.5)),
            ]
            for wire in fan {
                wires.move(to: wire.start)
                wires.curve(to: wire.end, controlPoint1: wire.c1, controlPoint2: wire.c2)
            }
            wires.stroke()
            for wire in fan {
                NSBezierPath(ovalIn: NSRect(x: wire.end.x - 1.1, y: wire.end.y - 1.1, width: 2.2, height: 2.2)).fill()
            }

            if let dot = Self.color(for: health) {
                dot.setFill()
                NSBezierPath(ovalIn: NSRect(x: 14.5, y: 0.5, width: 6, height: 6)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func color(for health: FleetHealth) -> NSColor? {
        switch health {
        case .idle: nil
        case .healthy: .systemGreen
        case .starting: .systemYellow
        case .unhealthy: .systemRed
        }
    }
}
