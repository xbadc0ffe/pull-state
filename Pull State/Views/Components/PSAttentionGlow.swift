import SwiftUI

/// Soft, repeating accent glow drawn behind something the user still needs to
/// set up — the Log screen's Machine / Grinder / Beans rows while none exist.
/// Cycles continuously via `PhaseAnimator`; with Reduce Motion on it holds a
/// steady highlight instead of pulsing.
struct PSAttentionGlow: View {
    var cornerRadius: CGFloat = 12
    @Environment(\.psPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            glow(lit: true)
        } else {
            PhaseAnimator([false, true]) { lit in
                glow(lit: lit)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        }
    }

    private func glow(lit: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.accent.opacity(lit ? 0.16 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.accent.opacity(lit ? 0.8 : 0.25), lineWidth: 1)
            )
            .shadow(color: palette.accent.opacity(lit ? 0.45 : 0), radius: lit ? 6 : 0)
    }
}
