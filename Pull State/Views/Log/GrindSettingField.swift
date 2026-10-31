import SwiftUI

/// Free-text "Grind Setting" row at the top of a Settings card (e.g. "22",
/// "1.4.2"). Shared by the Log screen and Shot edit so both read the same.
struct GrindSettingField: View {
    @Binding var text: String
    @Environment(\.psPalette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Grind Setting")
                .font(PSFont.body(13, weight: .medium))
                .foregroundStyle(palette.inkSoft)
            Spacer(minLength: 12)
            TextField("e.g. 22", text: $text)
                .font(PSFont.mono(15, weight: .semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .accessibilityLabel("Grind Setting")
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(palette.line)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
