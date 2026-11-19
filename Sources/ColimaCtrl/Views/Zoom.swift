import SwiftUI

private struct UIZoomKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }

extension EnvironmentValues {
    var uiZoom: CGFloat {
        get { self[UIZoomKey.self] }
        set { self[UIZoomKey.self] = newValue }
    }
}

/// A font description that scales with the window's zoom. Dynamic Type does nothing on macOS, so the app's text sizes come from here.
struct ZoomFont {
    var size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default

    static let caption = ZoomFont(size: 10)
    static let subheadline = ZoomFont(size: 11)
    static let callout = ZoomFont(size: 12)
    static let headline = ZoomFont(size: 13, weight: .semibold)
    static let title3 = ZoomFont(size: 15)
    static let title2 = ZoomFont(size: 17)

    static func system(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> ZoomFont {
        ZoomFont(size: size, weight: weight, design: design)
    }

    func weight(_ weight: Font.Weight) -> ZoomFont {
        var copy = self
        copy.weight = weight
        return copy
    }

    func font(zoom: CGFloat) -> Font { .system(size: size * zoom, weight: weight, design: design) }
}

private struct ZoomFontModifier: ViewModifier {
    @Environment(\.uiZoom) private var zoom
    let font: ZoomFont

    func body(content: Content) -> some View { content.font(font.font(zoom: zoom)) }
}

extension View {
    func zoomFont(_ font: ZoomFont) -> some View { modifier(ZoomFontModifier(font: font)) }
}

enum Zoom {
    static let levels: [Double] = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]

    /// Native controls come in a few sizes, so zoom picks the nearest one.
    static func controlSize(for zoom: Double) -> ControlSize {
        switch zoom {
        case ..<0.95: .small
        case ..<1.2: .regular
        case ..<1.6: .large
        default: .extraLarge
        }
    }

    static func step(_ current: Double, by delta: Int) -> Double {
        let index = levels.enumerated().min { abs($0.element - current) < abs($1.element - current) }?.offset ?? 2
        return levels[min(max(index + delta, 0), levels.count - 1)]
    }
}
