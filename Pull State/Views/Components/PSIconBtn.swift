import SwiftUI

struct PSIconBtn: View {
    let systemName: String
    var label: String = ""
    var size: CGFloat = 32
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(palette.ink)
                .frame(width: size, height: size)
                .background(palette.surface, in: Circle())
                .overlay(
                    Circle().strokeBorder(palette.line, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? systemName : label)
    }
}

struct PSTextBtn: View {
    let label: String
    var bold: Bool = false
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PSFont.body(14, weight: bold ? .bold : .regular))
                .foregroundStyle(palette.accent)
        }
        .buttonStyle(.plain)
    }
}
