import SwiftUI

extension View {
    /// Content-layer card. Glass is reserved for controls and navigation; it is costly to render in scrolling content.
    func contentCard(cornerRadius: CGFloat = 14) -> some View {
        background(.quaternary.opacity(0.55), in: .rect(cornerRadius: cornerRadius))
            .background(Brand.blue.opacity(0.07), in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Brand.blue.opacity(0.22), lineWidth: 0.5))
    }
}
