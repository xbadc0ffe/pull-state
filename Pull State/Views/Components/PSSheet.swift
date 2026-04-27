import SwiftUI

struct PSSheet<Content: View>: View {
    let title: String?
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.lineStrong)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if let title {
                HStack {
                    PSDisplay(title, size: 20)
                    Spacer()
                    Button("Close", action: onClose)
                        .font(PSFont.body(14))
                        .foregroundStyle(palette.inkSoft)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }

            content()
        }
        .background(palette.surface)
    }
}
