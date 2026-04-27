import SwiftUI

struct PSCard<Content: View>: View {
    var soft: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.psPalette) private var palette

    var body: some View {
        content()
            .background(palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 0.5)
            )
            .psShadow(strong: !soft)
    }
}
