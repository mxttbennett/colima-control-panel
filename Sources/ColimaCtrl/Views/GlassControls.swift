import SwiftUI

/// A segmented control whose selection is one glass capsule that flows between options.
struct GlassSegmented<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(options) { option in
                    let selected = option == selection
                    Text(title(option))
                        .font(.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 18).padding(.vertical, 6)
                        .glassEffect(selected ? Glass.regular.tint(Brand.blue.opacity(0.4)).interactive() : Glass.identity, in: .capsule)
                        .glassEffectID(selected ? "selection" : "option-\(option.id)", in: namespace)
                        .contentShape(.capsule)
                        .onTapGesture { withAnimation(.bouncy(duration: 0.4)) { selection = option } }
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(3)
            .background(.quaternary.opacity(0.6), in: .capsule)
        }
    }
}

/// Neutral glass capsule button. Tint is only for meaning, such as red for removal, so the app's accent never floods a control.
struct LiquidButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        LiquidButtonBody(configuration: configuration, tint: tint)
    }
}

private struct LiquidButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color?
    @Environment(\.isEnabled) private var enabled
    @Environment(\.controlSize) private var size

    var body: some View {
        let compact = size == .small || size == .mini
        let glass: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
        configuration.label
            .font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
            .foregroundStyle(tint ?? Color.primary)
            .padding(.horizontal, compact ? 10 : 14).padding(.vertical, compact ? 4 : 6)
            .glassEffect(glass.interactive(), in: .capsule)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.bouncy(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidButtonStyle {
    static var liquid: LiquidButtonStyle { LiquidButtonStyle() }
    static func liquid(tint: Color) -> LiquidButtonStyle { LiquidButtonStyle(tint: tint) }
}

/// Soft colored light behind the window so glass has something to refract.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Brand.blue.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 720)
            RadialGradient(colors: [Brand.mint.opacity(0.09), .clear], center: .bottomLeading, startRadius: 0, endRadius: 680)
            RadialGradient(colors: [Brand.pink.opacity(0.05), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}
