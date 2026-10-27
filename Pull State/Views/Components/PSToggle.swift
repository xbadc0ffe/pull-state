import SwiftUI

/// Custom switch matching the warm palette. `label` is only used for
/// VoiceOver (the visible label is rendered by the caller's row), via an
/// accessibility representation so the control reads as a real switch with
/// an on/off value.
struct PSToggle: View {
    @Binding var isOn: Bool
    var label: String = ""
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isOn ? palette.accent : palette.surfaceAlt)
                    .frame(width: 44, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(palette.lineStrong, lineWidth: 0.5)
                    )
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(label, isOn: $isOn)
        }
    }
}
