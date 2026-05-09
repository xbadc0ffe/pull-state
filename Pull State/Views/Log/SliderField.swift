import SwiftUI

/// Stepped slider with an inline editable readout. There is no hidden `Slider`
/// — the visible thumb is the only thing that exists, and a `DragGesture` on
/// the visual track maps drag x-position to a stepped, clamped value. Tap on
/// the readout flips the row into a focused decimal text field that commits
/// on submit/blur.
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
    @State private var dragActive: Bool? = nil
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
                // simultaneousGesture lets the parent ScrollView still receive
                // vertical drags — `dragActive` decides whether *this* gesture
                // commits a value change. Direction gating keeps vertical
                // scroll smooth even when the touch started inside the knob's
                // tolerance zone.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if dragActive == nil {
                                let dx = abs(g.translation.width)
                                let dy = abs(g.translation.height)
                                // Defer the decision until the user has
                                // actually moved — direction is ambiguous on
                                // the very first touch sample.
                                if dx < 4 && dy < 4 { return }

                                let halfThumb: CGFloat = 9
                                let forgiveness: CGFloat = 12
                                let unclampedCenter = trackWidth * fraction
                                let thumbCenter = max(halfThumb, min(trackWidth - halfThumb, unclampedCenter))
                                let tolerance = halfThumb + forgiveness
                                let inTolerance = abs(g.startLocation.x - thumbCenter) <= tolerance
                                dragActive = inTolerance && dx > dy
                            }
                            if dragActive == true {
                                update(from: g.location.x, width: trackWidth)
                            }
                        }
                        .onEnded { _ in
                            dragActive = nil
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
