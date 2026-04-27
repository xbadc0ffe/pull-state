import SwiftUI

struct PSRoastBadge: View {
    let level: Roast
    @Environment(\.psPalette) private var palette

    private var pip: Color {
        switch level {
        case .light:  return Color(hex: 0xCEA16D)
        case .medium: return Color(hex: 0x7D4A26)
        case .dark:   return Color(hex: 0x3A1F12)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(pip)
                .frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
            Text(level.rawValue.uppercased())
                .font(PSFont.mono(9.5))
                .tracking(0.8)
                .foregroundStyle(palette.inkSoft)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.line, lineWidth: 0.5))
    }
}
