import SwiftUI

/// The icon's palette, used in small touches so the app keeps its quiet base.
enum Brand {
    static let blue = Color(red: 0.18, green: 0.38, blue: 0.98)
    static let mint = Color(red: 0.0, green: 0.80, blue: 0.74)
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.62)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.0)
    static let green = Color(red: 0.0, green: 0.76, blue: 0.28)
}

extension Section {
    var color: Color {
        switch self {
        case .containers: Brand.blue
        case .volumes: Brand.mint
        case .images: Brand.orange
        case .networks: Brand.pink
        case .system: Brand.green
        }
    }
}
