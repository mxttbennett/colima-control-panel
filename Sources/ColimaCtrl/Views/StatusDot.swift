import SwiftUI
import ColimaCtrlCore

extension DisplayState {
    var color: Color {
        switch self {
        case .running: .green
        case .starting, .restarting, .paused: .yellow
        case .unhealthy: .red
        case .stopped: Color(nsColor: .tertiaryLabelColor)
        }
    }
}

extension FleetHealth {
    var color: Color? {
        switch self {
        case .idle: nil
        case .healthy: .green
        case .starting: .yellow
        case .unhealthy: .red
        }
    }

    var label: String {
        switch self {
        case .idle: "Nothing running"
        case .healthy: "All running containers are healthy"
        case .starting: "A container is starting"
        case .unhealthy: "A container is unhealthy"
        }
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 9
    var label: String?

    var body: some View {
        let dot = Circle().fill(color).frame(width: size, height: size)
        if let label {
            dot.help(label).accessibilityLabel(label)
        } else {
            dot.accessibilityHidden(true)
        }
    }
}
