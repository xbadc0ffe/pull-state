import SwiftUI

/// Per-bean rating trend chart shown on the Bean detail. Sized for ten visible
/// shots; once the bean has more than ten, the plot becomes horizontally
/// scrollable and starts scrolled to the trailing edge so the newest pulls
/// are visible. The line is a Catmull-Rom curve (factor 1/6) that passes
/// exactly through every point — see DESIGN.md §3.3.
struct RatingChart: View {
    let points: [BeanRatingPoint]
    @Environment(\.psPalette) private var palette

    private let leftPad: CGFloat = 28
    private let rightPad: CGFloat = 18
    private let topPad: CGFloat = 6
    private let bottomPad: CGFloat = 18
    private let visibleSlots: Int = 10
    private let scrollEndID = "ratingChartEnd"

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let visibleW = proxy.size.width
            let plotH = max(0, h - topPad - bottomPad)
            let visiblePlotW = max(0, visibleW - leftPad - rightPad)
            let slotW = visiblePlotW / CGFloat(visibleSlots)
            let slotCount = max(points.count, visibleSlots)
            let contentPlotW = slotW * CGFloat(slotCount)

            HStack(spacing: 0) {
                yAxisColumn(plotH: plotH, h: h)
                    .frame(width: leftPad)
                ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        plotContent(plotH: plotH, slotW: slotW, contentPlotW: contentPlotW, h: h)
                            .frame(width: contentPlotW + rightPad, height: h)
                            .id(scrollEndID)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            reader.scrollTo(scrollEndID, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(height: 120)
    }

    @ViewBuilder
    private func yAxisColumn(plotH: CGFloat, h: CGFloat) -> some View {
        ZStack {
            ForEach(1...5, id: \.self) { n in
                let y = topPad + plotH - (CGFloat(n - 1) / 4.0) * plotH
                Text("\(n)★")
                    .font(PSFont.mono(8))
                    .foregroundStyle(palette.inkMuted)
                    .position(x: leftPad - 12, y: y)
            }
        }
        .frame(height: h)
    }

    @ViewBuilder
    private func plotContent(plotH: CGFloat, slotW: CGFloat, contentPlotW: CGFloat, h: CGFloat) -> some View {
        let xs: [CGFloat] = points.indices.map { idx in
            (CGFloat(idx) + 0.5) * slotW
        }
        let ys: [CGFloat] = points.map { p in
            topPad + plotH - (CGFloat(p.rating - 1) / 4.0) * plotH
        }
        let plotPoints: [CGPoint] = zip(xs, ys).map { CGPoint(x: $0, y: $1) }
        let curve = catmullRomPath(plotPoints)
        let baselineY = topPad + plotH

        ZStack {
            ForEach(1...5, id: \.self) { n in
                let y = topPad + plotH - (CGFloat(n - 1) / 4.0) * plotH
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: contentPlotW + rightPad, y: y))
                }
                .stroke(palette.line, style: StrokeStyle(lineWidth: 0.5, dash: (n == 1 || n == 5) ? [] : [2, 3]))
            }

            if plotPoints.count >= 2 {
                areaPath(curve: curve, points: plotPoints, baselineY: baselineY)
                    .fill(palette.accent.opacity(0.12))

                curve
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

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

    private func areaPath(curve: Path, points: [CGPoint], baselineY: CGFloat) -> Path {
        var path = curve
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.addLine(to: CGPoint(x: first.x, y: baselineY))
        path.closeSubpath()
        return path
    }

    private func catmullRomPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count >= 2 else { return path }

        for i in 0..<(points.count - 1) {
            let p0 = i == 0 ? points[i] : points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}
