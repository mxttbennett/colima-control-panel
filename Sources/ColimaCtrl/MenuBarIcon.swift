import AppKit
import ColimaCtrlCore

@MainActor
enum MenuBarIcon {
    /// A jellyfish in the menu bar's label color. Its core takes the fleet's status color.
    static func image(for health: FleetHealth) -> NSImage {
        let size = NSSize(width: 21, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.set()

            let bell = NSBezierPath()
            bell.lineWidth = 1.3
            bell.lineJoinStyle = .round
            bell.move(to: NSPoint(x: 2.8, y: 9.4))
            bell.curve(to: NSPoint(x: 18.2, y: 9.4), controlPoint1: NSPoint(x: 2.8, y: 18.6), controlPoint2: NSPoint(x: 18.2, y: 18.6))
            bell.curve(to: NSPoint(x: 2.8, y: 9.4), controlPoint1: NSPoint(x: 13.6, y: 8.0), controlPoint2: NSPoint(x: 7.4, y: 8.0))
            bell.close()
            bell.stroke()

            let tentacles = NSBezierPath()
            tentacles.lineWidth = 1.15
            tentacles.lineCapStyle = .round
            for (index, x) in [5.4, 8.0, 10.5, 13.0, 15.6].enumerated() {
                let bend: CGFloat = index % 2 == 0 ? 1.3 : -1.3
                let reach: CGFloat = index == 2 ? 0.6 : 1.8
                tentacles.move(to: NSPoint(x: x, y: 8.2))
                tentacles.curve(to: NSPoint(x: x, y: reach), controlPoint1: NSPoint(x: x + bend, y: 6.0), controlPoint2: NSPoint(x: x - bend, y: 3.2))
            }
            tentacles.stroke()

            Self.coreColor(for: health).setFill()
            NSBezierPath(ovalIn: NSRect(x: 10.5 - 1.7, y: 12.3 - 1.7, width: 3.4, height: 3.4)).fill()
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
