import SwiftUI

/// Circular icon button used in nav bars. `label` is the VoiceOver name and
/// is required at every call site — an SF Symbol name like "ellipsis" is not
/// an acceptable accessibility label.
struct PSIconBtn: View {
    let systemName: String
    let label: String
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
        .accessibilityLabel(label)
    }
}
