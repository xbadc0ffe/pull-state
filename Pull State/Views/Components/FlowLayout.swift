import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                width = max(width, lineWidth - spacing)
                height += lineHeight + lineSpacing
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        width = max(width, lineWidth - spacing)
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var lines: [[(index: Int, size: CGSize)]] = []
        var current: [(index: Int, size: CGSize)] = []
        var currentWidth: CGFloat = 0

        for (idx, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let added = current.isEmpty ? size.width : currentWidth + spacing + size.width
            if added > maxWidth, !current.isEmpty {
                lines.append(current)
                current = [(idx, size)]
                currentWidth = size.width
            } else {
                current.append((idx, size))
                currentWidth = added
            }
        }
        if !current.isEmpty { lines.append(current) }

        var y = bounds.minY
        for line in lines {
            let lineWidth = line.reduce(CGFloat(0)) { $0 + $1.size.width }
                + CGFloat(max(0, line.count - 1)) * spacing
            let lineHeight = line.map { $0.size.height }.max() ?? 0
            var x: CGFloat
            switch alignment {
            case .center:
                x = bounds.minX + max(0, (maxWidth - lineWidth) / 2)
            case .trailing:
                x = bounds.minX + max(0, maxWidth - lineWidth)
            default:
                x = bounds.minX
            }
            for entry in line {
                subviews[entry.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(entry.size))
                x += entry.size.width + spacing
            }
            y += lineHeight + lineSpacing
        }
    }
}
