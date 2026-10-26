import SwiftUI

/// The icon's palette, used in small touches so the app keeps its quiet base.
enum Brand {
    static let blue = Color(red: 0.33, green: 0.47, blue: 0.98)
    static let mint = Color(red: 0.37, green: 0.88, blue: 0.82)
    static let pink = Color(red: 1.0, green: 0.37, blue: 0.78)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.04)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
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
