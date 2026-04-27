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

    private var displayLow: Double { min(range.lowerBound, value) }
    private var displayHigh: Double { max(range.upperBound, value) }

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

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.surfaceAlt)
                    .frame(height: 4)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(palette.line, lineWidth: 0.5))
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [palette.accent, palette.accentDeep], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * fraction, height: 4)
                }
                .frame(height: 4)
                Slider(value: $value, in: displayLow...displayHigh, step: step)
                    .tint(palette.accent)
                    .opacity(0.001) // hit target only — visual is custom
                    .frame(height: 22)
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
        String(format: "%.*f", decimals, value)
    }
    private var fraction: Double {
        let span = displayHigh - displayLow
        return span > 0 ? (value - displayLow) / span : 0
    }
    private func commit() {
        defer { editing = false }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let n = Double(trimmed) else { return }
        value = n
    }
}
