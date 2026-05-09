import SwiftUI

struct SortSheet: View {
    @Binding var sortBy: SortOrder
    let onClose: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PSDisplay("Sort by", size: 20)
                Spacer()
                Button("Close", action: onClose)
                    .font(PSFont.body(14))
                    .foregroundStyle(palette.inkSoft)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .psContentColumn()

            VStack(spacing: 8) {
                ForEach(SortOrder.allCases) { order in
                    Button {
                        sortBy = order
                        onClose()
                    } label: {
                        HStack {
                            Text(order.label)
                                .font(PSFont.body(14, weight: .semibold))
                                .foregroundStyle(sortBy == order ? palette.accentDeep : palette.ink)
                            Spacer()
                            if sortBy == order {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(palette.accentDeep)
                            }
                        }
                        .padding(14)
                        .background(sortBy == order ? palette.accentSoft : palette.card,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(sortBy == order ? palette.accent : palette.line, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .psContentColumn()

            Spacer()
        }
    }
}
