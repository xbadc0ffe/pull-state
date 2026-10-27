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

/// A `PSSectionLabel` over its content, with the 4 pt label inset and 8 pt
/// gap every screen uses. `topPad` adds breathing room above the label for
/// stacked sections on detail screens.
struct PSSection<Content: View>: View {
    let label: String
    var topPad: CGFloat = 0
    @ViewBuilder var content: () -> Content

    init(_ label: String, topPad: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.topPad = topPad
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
        .padding(.top, topPad)
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
