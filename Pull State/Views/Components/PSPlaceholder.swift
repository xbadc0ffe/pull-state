import SwiftUI

struct PSPlaceholder: View {
    var label: String? = nil
    var radius: CGFloat = 10
    @Environment(\.psPalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Diagonal stripes
            DiagonalStripes(colorA: palette.placeholderA, colorB: palette.placeholderB)
            // Vignette
            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let label {
                Text(label.uppercased())
                    .font(PSFont.mono(8))
                    .tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 0.5)
        )
    }
}

private struct DiagonalStripes: View {
    let colorA: Color
    let colorB: Color
    var stripeWidth: CGFloat = 12

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colorA))
            let diag = sqrt(size.width * size.width + size.height * size.height)
            let count = Int(ceil(diag / stripeWidth)) * 2
            ctx.translateBy(x: -diag / 2, y: 0)
            ctx.rotate(by: .degrees(45))
            for i in 0..<count where i.isMultiple(of: 2) {
                let rect = CGRect(
                    x: CGFloat(i) * stripeWidth,
                    y: -diag,
                    width: stripeWidth,
                    height: diag * 3
                )
                ctx.fill(Path(rect), with: .color(colorB))
            }
        }
    }
}
