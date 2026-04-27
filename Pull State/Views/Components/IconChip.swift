import SwiftUI

struct IconChip: View {
    let systemName: String
    let label: String
    var badge: Int? = nil
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    private var hasBadge: Bool { (badge ?? 0) > 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(PSFont.body(12, weight: .semibold))
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(PSFont.mono(9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(palette.accent, in: Capsule())
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(hasBadge ? palette.accentDeep : palette.ink)
            .background(hasBadge ? palette.accentSoft : palette.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(hasBadge ? palette.accent : palette.lineStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let label: String
    let value: String
    var suffix: String? = nil
    var accent: Bool = false
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(PSFont.mono(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(accent ? palette.accentDeep : palette.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(PSFont.display(24, weight: .bold))
                    .foregroundStyle(palette.ink)
                if let suffix {
                    Text(suffix)
                        .font(PSFont.mono(10))
                        .foregroundStyle(palette.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accent ? palette.accentSoft : palette.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent ? palette.accent : palette.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .psShadow(strong: false)
    }
}
