import SwiftUI

struct SliderField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var decimals: Int = 1
    var last: Bool = false

    @Environment(\.psPalette) private var palette
    @State private var editing = false
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    private var clampedValue: Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        return span > 0 ? (clampedValue - range.lowerBound) / span : 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PSFont.body(13, weight: .medium))
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                if editing {
                    HStack(spacing: 4) {
                        TextField("", text: $draft)
                            .modifier(PSDecimalKeyboard(active: true))
                            .font(PSFont.mono(17, weight: .bold))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.trailing)
                            .focused($focused)
                            .frame(width: 70)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onSubmit { commit() }
                        Text(unit)
                            .font(PSFont.mono(11))
                            .foregroundStyle(palette.inkMuted)
                    }
                    .onAppear {
                        draft = formatted
                        focused = true
                    }
                    .onChange(of: focused) { _, new in
                        if !new { commit() }
                    }
                } else {
                    Button {
                        editing = true
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatted)
                                .font(PSFont.mono(17, weight: .bold))
                                .foregroundStyle(palette.ink)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    Rectangle()
                                        .fill(palette.lineStrong)
                                        .frame(height: 1)
                                        .padding(.horizontal, 6),
                                    alignment: .bottom
                                )
                            Text(unit)
                                .font(PSFont.mono(11))
                                .foregroundStyle(palette.inkMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette.surfaceAlt)
                        .frame(height: 4)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(palette.line, lineWidth: 0.5))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [palette.accent, palette.accentDeep], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, trackWidth * fraction), height: 4)

                    Circle()
                        .fill(palette.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                        .psShadow(strong: false)
                        .offset(x: max(0, min(trackWidth - 18, trackWidth * fraction - 9)))
                }
                .frame(height: 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            update(from: g.location.x, width: trackWidth)
                        }
                )
            }
            .frame(height: 22)
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(last ? .clear : palette.line)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var formatted: String {
        String(format: "%.*f", decimals, clampedValue)
    }

    private func update(from x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let f = max(0, min(1, x / width))
        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
        let stepped = (raw / step).rounded() * step
        let clamped = min(max(stepped, range.lowerBound), range.upperBound)
        if abs(clamped - value) > 1e-9 {
            value = clamped
        }
    }

    private func commit() {
        defer { editing = false }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let n = Double(trimmed) else { return }
        value = min(max(n, range.lowerBound), range.upperBound)
    }
}
