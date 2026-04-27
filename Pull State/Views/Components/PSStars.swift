import SwiftUI

struct PSStars: View {
    @Binding var value: Int
    var size: CGFloat = 22
    var readOnly: Bool = false
    @Environment(\.psPalette) private var palette

    init(value: Binding<Int>, size: CGFloat = 22, readOnly: Bool = false) {
        self._value = value
        self.size = size
        self.readOnly = readOnly
    }

    init(staticValue: Int, size: CGFloat = 22) {
        self._value = .constant(staticValue)
        self.size = size
        self.readOnly = true
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { n in
                let filled = n <= value
                Group {
                    if readOnly {
                        starShape(filled: filled)
                    } else {
                        Button {
                            value = (n == value) ? 0 : n
                        } label: {
                            starShape(filled: filled)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(value) of 5 stars")
    }

    @ViewBuilder
    private func starShape(filled: Bool) -> some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: size))
            .foregroundStyle(filled ? palette.accent : palette.inkMuted)
    }
}
