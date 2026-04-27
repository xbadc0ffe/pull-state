import SwiftUI

struct DualTrackTimer: View {
    let preInfusion: Double
    let pullTime: Double
    let running: Bool
    let phase: TimerPhase
    let done: Bool
    let editable: Bool
    let onManualPre: (Double) -> Void
    let onManualPull: (Double) -> Void

    @Environment(\.psPalette) private var palette
    @State private var pulse = false

    private var totalSec: Double { preInfusion + pullTime }
    private var status: String {
        if done { return "DONE" }
        if running { return phase == .pre ? "PRE-INFUSION" : "PULLING" }
        return "READY"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", totalSec))
                        .font(PSFont.display(44, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .monospacedDigit()
                    Text("SEC")
                        .font(PSFont.mono(12))
                        .foregroundStyle(palette.inkMuted)
                }
                Spacer()
                HStack(spacing: 6) {
                    if running {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulse ? 1.15 : 0.85)
                            .opacity(pulse ? 1 : 0.45)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                                    pulse = true
                                }
                            }
                            .onDisappear { pulse = false }
                    }
                    Text(status)
                        .font(PSFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(running ? palette.accent : palette.inkMuted)
                }
            }

            TimerTrack(
                label: "PRE-INFUSION",
                value: preInfusion,
                fraction: min(preInfusion / 10, 1),
                active: running && phase == .pre,
                editable: editable,
                onCommit: onManualPre
            )
            TimerTrack(
                label: "PULL",
                value: pullTime,
                fraction: min(pullTime / 30, 1),
                active: running && phase == .pull,
                editable: editable,
                onCommit: onManualPull
            )
        }
    }
}

struct TimerTrack: View {
    let label: String
    let value: Double
    let fraction: Double
    let active: Bool
    let editable: Bool
    let onCommit: (Double) -> Void

    @Environment(\.psPalette) private var palette
    @State private var editing = false
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PSFont.mono(9.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(active ? palette.accent : palette.inkMuted)
                Spacer()
                if editing {
                    HStack(spacing: 2) {
                        TextField("", text: $draft)
                            .modifier(PSDecimalKeyboard(active: true))
                            .font(PSFont.mono(13, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.trailing)
                            .focused($focused)
                            .frame(width: 56)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6).strokeBorder(palette.accent, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit { commit() }
                        Text("s")
                            .font(PSFont.mono(13, weight: .semibold))
                            .foregroundStyle(palette.inkSoft)
                    }
                    .onAppear {
                        draft = value > 0 ? String(format: "%.1f", value) : ""
                        focused = true
                    }
                    .onChange(of: focused) { _, newValue in
                        if !newValue { commit() }
                    }
                } else {
                    Button {
                        if editable { editing = true }
                    } label: {
                        Text(String(format: "%.1fs", value))
                            .font(PSFont.mono(13, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                            .overlay(
                                Rectangle()
                                    .fill(editable ? palette.lineStrong : .clear)
                                    .frame(height: 1)
                                    .padding(.horizontal, 4),
                                alignment: .bottom
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!editable)
                }
            }
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(palette.surfaceAlt)
                    .frame(height: 8)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(palette.line, lineWidth: 0.5))
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [palette.accent, palette.accentDeep], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * fraction, height: 8)
                        .shadow(color: active ? palette.accent.opacity(0.4) : .clear, radius: 4)
                }
                .frame(height: 8)
            }
        }
    }

    private func commit() {
        defer { editing = false }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let n = Double(trimmed) else { return }
        onCommit(n)
    }
}

struct TimerBtn: View {
    let label: String
    let primary: Bool
    let disabled: Bool
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PSFont.mono(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(primary ? Color.white : (disabled ? palette.inkMuted : palette.ink))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    primary ? palette.accent : (disabled ? palette.surfaceAlt : palette.surface),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(primary ? Color.clear : palette.line, lineWidth: 0.5)
                )
                .opacity(disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .psShadow(strong: primary)
    }
}
