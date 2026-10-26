import AppKit
import ColimaCtrlCore

@MainActor
enum MenuBarIcon {
    /// Three orbs joined by wires, drawn in the menu bar's label color. The cores take the fleet's status color.
    static func image(for health: FleetHealth) -> NSImage {
        let size = NSSize(width: 21, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.set()
            let wires = NSBezierPath()
            wires.lineWidth = 1.1
            wires.lineCapStyle = .round
            wires.move(to: NSPoint(x: 8.2, y: 11.0))
            wires.curve(to: NSPoint(x: 5.6, y: 7.9), controlPoint1: NSPoint(x: 6.3, y: 11.8), controlPoint2: NSPoint(x: 7.0, y: 8.6))
            wires.move(to: NSPoint(x: 12.8, y: 11.0))
            wires.curve(to: NSPoint(x: 16.0, y: 7.9), controlPoint1: NSPoint(x: 15.0, y: 11.8), controlPoint2: NSPoint(x: 14.2, y: 8.6))
            wires.move(to: NSPoint(x: 8.3, y: 4.3))
            wires.curve(to: NSPoint(x: 13.5, y: 4.3), controlPoint1: NSPoint(x: 9.2, y: 1.7), controlPoint2: NSPoint(x: 12.0, y: 6.9))
            wires.stroke()

            let orbs: [(center: NSPoint, radius: CGFloat)] = [
                (NSPoint(x: 10.5, y: 13.2), 3.6), (NSPoint(x: 4.6, y: 4.8), 3.7), (NSPoint(x: 17.0, y: 4.8), 3.4),
            ]
            let core = Self.coreColor(for: health)
            for orb in orbs {
                let outline = NSBezierPath(ovalIn: NSRect(x: orb.center.x - orb.radius, y: orb.center.y - orb.radius, width: orb.radius * 2, height: orb.radius * 2))
                outline.lineWidth = 1.2
                outline.stroke()
                core.setFill()
                NSBezierPath(ovalIn: NSRect(x: orb.center.x - 1.4, y: orb.center.y - 1.4, width: 2.8, height: 2.8)).fill()
                NSColor.labelColor.set()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func coreColor(for health: FleetHealth) -> NSColor {
        switch health {
        case .idle: NSColor.labelColor.withAlphaComponent(0.45)
        case .healthy: .systemGreen
        case .starting: .systemYellow
        case .unhealthy: .systemRed
        }
    }
}
