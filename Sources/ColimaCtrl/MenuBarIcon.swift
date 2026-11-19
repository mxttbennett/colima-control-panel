import AppKit
import ColimaCtrlCore

@MainActor
enum MenuBarIcon {
    /// An octopus in the menu bar's label color. Its head takes the fleet's status color.
    static func image(for health: FleetHealth) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            drawOctopus(headColor: coreColor(for: health))
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The app icon's arm, scaled to the menu bar and turned around the center for each of the eight arms.
    static func drawOctopus(headColor: NSColor) {
        let scale: CGFloat = 8.4 / 400
        let center = NSPoint(x: 9, y: 9)
        let controls: [(NSPoint, NSPoint, NSPoint)] = [
            (NSPoint(x: 470, y: 360), NSPoint(x: 560, y: 290), NSPoint(x: 520, y: 220)),
            (NSPoint(x: 495, y: 170), NSPoint(x: 540, y: 120), NSPoint(x: 585, y: 150)),
        ]

        func place(_ point: NSPoint, angle: CGFloat) -> NSPoint {
            let dx = point.x - 512
            let dy = point.y - 512
            let x = dx * cos(angle) - dy * sin(angle)
            let y = dx * sin(angle) + dy * cos(angle)
            return NSPoint(x: center.x + x * scale, y: center.y - y * scale)
        }

        NSColor.labelColor.set()
        let arms = NSBezierPath()
        arms.lineWidth = 1.3
        arms.lineCapStyle = .round
        arms.lineJoinStyle = .round
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            arms.move(to: place(NSPoint(x: 512, y: 440), angle: angle))
            for (first, second, end) in controls {
                arms.curve(to: place(end, angle: angle), controlPoint1: place(first, angle: angle), controlPoint2: place(second, angle: angle))
            }
        }
        arms.stroke()

        headColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 3.3, y: center.y - 3.3, width: 6.6, height: 6.6)).fill()
    }

    private static func coreColor(for health: FleetHealth) -> NSColor {
        switch health {
        case .idle: NSColor.labelColor.withAlphaComponent(0.55)
        case .healthy: .systemGreen
        case .starting: .systemYellow
        case .unhealthy: .systemRed
        }
    }
}
