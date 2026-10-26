import AppKit
import ColimaCtrlCore

@MainActor
enum MenuBarIcon {
    /// A synth module with patch cables out of every side, drawn in the menu bar's label color, with a colored status dot.
    static func image(for health: FleetHealth) -> NSImage {
        let size = NSSize(width: 21, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.set()
            let module = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 5, width: 9, height: 7), xRadius: 1.2, yRadius: 1.2)
            module.lineWidth = 1.4
            module.stroke()
            NSBezierPath(ovalIn: NSRect(x: 7.8, y: 7.3, width: 2.4, height: 2.4)).fill()

            let cables = NSBezierPath()
            cables.lineWidth = 1.2
            cables.lineCapStyle = .round
            let routes: [(from: NSPoint, c1: NSPoint, c2: NSPoint, to: NSPoint)] = [
                (NSPoint(x: 4.5, y: 10.5), NSPoint(x: 2, y: 11), NSPoint(x: 0.8, y: 12.5), NSPoint(x: 1.8, y: 15)),
                (NSPoint(x: 4.5, y: 6.5), NSPoint(x: 2, y: 6), NSPoint(x: 0.8, y: 4.5), NSPoint(x: 1.8, y: 2)),
                (NSPoint(x: 13.5, y: 10.5), NSPoint(x: 16, y: 11), NSPoint(x: 17.2, y: 12.5), NSPoint(x: 16.2, y: 15)),
                (NSPoint(x: 9, y: 12), NSPoint(x: 8.5, y: 14), NSPoint(x: 10, y: 15.5), NSPoint(x: 9, y: 17)),
                (NSPoint(x: 9, y: 5), NSPoint(x: 8.5, y: 3.5), NSPoint(x: 10, y: 2.5), NSPoint(x: 9, y: 1)),
            ]
            for route in routes {
                cables.move(to: route.from)
                cables.curve(to: route.to, controlPoint1: route.c1, controlPoint2: route.c2)
            }
            cables.stroke()
            for route in routes {
                NSBezierPath(ovalIn: NSRect(x: route.to.x - 1.1, y: route.to.y - 1.1, width: 2.2, height: 2.2)).fill()
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
