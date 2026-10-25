import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var maximum: Double?
    var filled = true
    var color: Color = .accentColor

    var body: some View {
        Canvas { context, size in
            let top = max(maximum ?? (values.max() ?? 1), 1)
            let data = values.count > 1 ? values : [0, 0]
            let step = size.width / CGFloat(data.count - 1)
            var line = Path()
            for (index, value) in data.enumerated() {
                let point = CGPoint(x: CGFloat(index) * step, y: size.height - 2 - CGFloat(min(value, top) / top) * (size.height - 4))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            if filled {
                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                context.fill(area, with: .color(color.opacity(0.18)))
            }
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
