import SwiftUI

struct RatingChart: View {
    let points: [BeanRatingPoint]
    @Environment(\.psPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let pad: CGFloat = 18
            let leftPad: CGFloat = 28
            let bottomPad: CGFloat = 18
            let topPad: CGFloat = 6
            let w = proxy.size.width
            let h = proxy.size.height
            let plotW = w - leftPad - pad
            let plotH = h - topPad - bottomPad

            let count = max(points.count - 1, 1)
            let xs = points.enumerated().map { idx, _ in
                leftPad + CGFloat(idx) * (plotW / CGFloat(count))
            }
            let ys = points.map { p in
                topPad + plotH - (CGFloat(p.rating - 1) / 4.0) * plotH
            }

            ZStack {
                // Gridlines
                ForEach(1...5, id: \.self) { n in
                    let y = topPad + plotH - (CGFloat(n - 1) / 4.0) * plotH
                    Path { p in
                        p.move(to: CGPoint(x: leftPad, y: y))
                        p.addLine(to: CGPoint(x: w - pad, y: y))
                    }
                    .stroke(palette.line, style: StrokeStyle(lineWidth: 0.5, dash: (n == 1 || n == 5) ? [] : [2, 3]))

                    Text("\(n)★")
                        .font(PSFont.mono(8))
                        .foregroundStyle(palette.inkMuted)
                        .position(x: leftPad - 12, y: y)
                }

                // Filled area
                Path { p in
                    p.move(to: CGPoint(x: xs.first ?? 0, y: topPad + plotH))
                    for (i, _) in points.enumerated() {
                        p.addLine(to: CGPoint(x: xs[i], y: ys[i]))
                    }
                    p.addLine(to: CGPoint(x: xs.last ?? 0, y: topPad + plotH))
                    p.closeSubpath()
                }
                .fill(palette.accent.opacity(0.12))

                // Line
                Path { p in
                    for (i, _) in points.enumerated() {
                        let pt = CGPoint(x: xs[i], y: ys[i])
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Dots + x labels
                ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                    Circle()
                        .fill(palette.card)
                        .overlay(Circle().strokeBorder(palette.accent, lineWidth: 1.5))
                        .frame(width: 6.4, height: 6.4)
                        .position(x: xs[idx], y: ys[idx])
                    Text(PSFmt.shortDateMono(point.date))
                        .font(PSFont.mono(8))
                        .foregroundStyle(palette.inkMuted)
                        .position(x: xs[idx], y: h - 4)
                }
            }
        }
        .frame(height: 120)
    }
}
