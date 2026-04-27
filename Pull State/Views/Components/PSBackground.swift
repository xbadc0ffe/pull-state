import SwiftUI

struct PSContentColumn: ViewModifier {
    var maxWidth: CGFloat = 560
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    func psContentColumn(maxWidth: CGFloat = 560) -> some View {
        modifier(PSContentColumn(maxWidth: maxWidth))
    }
}

struct PSPageBackground: View {
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            palette.page
            // Warm radial wash, mirrors the body::before noise from the prototype
            RadialGradient(
                colors: [
                    Color(hex: 0xC8794A).opacity(scheme == .dark ? 0.08 : 0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.25, y: 0.30),
                startRadius: 0,
                endRadius: 350
            )
            RadialGradient(
                colors: [
                    Color(hex: scheme == .dark ? 0x783C1E : 0x8C5A3C).opacity(scheme == .dark ? 0.10 : 0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.75, y: 0.70),
                startRadius: 0,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}
