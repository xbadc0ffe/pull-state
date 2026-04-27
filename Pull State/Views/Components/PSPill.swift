import SwiftUI

enum PSPillTone {
    case neutral, sour, perfect, bitter
}

struct PSPill: View {
    let label: String
    var active: Bool = false
    var tone: PSPillTone = .neutral
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 7
    var fontSize: CGFloat = 12
    var action: (() -> Void)?
    @Environment(\.psPalette) private var palette

    private var activeBg: Color {
        switch tone {
        case .neutral: return palette.accent
        case .sour:    return palette.bad
        case .perfect: return palette.good
        case .bitter:  return Color(hex: 0x5D3A25)
        }
    }

    private var activeRing: Color { activeBg }

    var body: some View {
        let inner = Text(label)
            .font(PSFont.body(fontSize, weight: .semibold))
            .tracking(0.2)
            .foregroundStyle(active ? Color.white : palette.inkSoft)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? activeBg : palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(active ? activeRing : palette.line, lineWidth: 0.5)
            )
            .contentShape(Capsule())

        if let action {
            Button(action: action) { inner }
                .buttonStyle(.plain)
        } else {
            inner
        }
    }
}
