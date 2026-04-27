import SwiftUI

struct PSToggle: View {
    @Binding var isOn: Bool
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
    }
}
