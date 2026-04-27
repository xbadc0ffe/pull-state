import SwiftUI

struct PSNavBar<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var large: Bool = false
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.psPalette) private var palette

    init(
        title: String,
        subtitle: String? = nil,
        large: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.large = large
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 6 : 0) {
            ZStack {
                if !large {
                    Text(title)
                        .font(PSFont.body(15, weight: .semibold))
                        .foregroundStyle(palette.ink)
                }
                HStack {
                    HStack(spacing: 8) { leading() }
                    Spacer()
                    HStack(spacing: 8) { trailing() }
                }
            }
            .frame(minHeight: 36)

            if large {
                VStack(alignment: .leading, spacing: 4) {
                    PSDisplay(title, size: 32, weight: .semibold)
                    if let subtitle {
                        Text(subtitle)
                            .font(PSFont.body(12))
                            .foregroundStyle(palette.inkSoft)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, large ? 16 : 12)
        .padding(.top, large ? 10 : 6)
        .padding(.bottom, large ? 0 : 6)
    }
}
