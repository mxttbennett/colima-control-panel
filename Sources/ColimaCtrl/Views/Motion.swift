import SwiftUI

/// Short, non-bouncy motion that follows Reduce Motion.
enum Motion {
    static let quick = Animation.snappy(duration: 0.18)
    static let smooth = Animation.smooth(duration: 0.26)
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func motion<Value: Equatable>(_ animation: Animation = Motion.quick, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// Digits roll over instead of snapping when the text changes.
    func rollingNumbers<Value: Equatable>(_ value: Value) -> some View {
        contentTransition(.numericText()).motion(Motion.quick, value: value)
    }
}
