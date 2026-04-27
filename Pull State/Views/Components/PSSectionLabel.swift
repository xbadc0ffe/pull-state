import SwiftUI

struct PSSectionLabel: View {
    let text: String
    @Environment(\.psPalette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(PSFont.mono(10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(palette.inkMuted)
    }
}

struct PSDisplay: View {
    let text: String
    var size: CGFloat = 28
    var weight: Font.Weight = .semibold
    @Environment(\.psPalette) private var palette

    init(_ text: String, size: CGFloat = 28, weight: Font.Weight = .semibold) {
        self.text = text
        self.size = size
        self.weight = weight
    }

    var body: some View {
        Text(text)
            .font(PSFont.display(size, weight: weight))
            .tracking(-0.3)
            .foregroundStyle(palette.ink)
            .lineSpacing(0)
    }
}
