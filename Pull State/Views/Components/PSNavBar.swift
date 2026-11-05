import SwiftUI

/// Top bar for every screen. `large` is the tab-screen style: 48 pt icon
/// buttons in a row with a big serif title underneath. The default compact
/// style is for sub-pages (detail pages, add forms): leading and trailing
/// controls at the edges and the title centred between them.
///
/// Compact bars are sized by `PSNavMetrics`, 1.5× the original chrome, so
/// the back arrow is easy to hit and the title easy to read. Build their
/// controls from `PSNavBackButton`, `PSNavTextButton` and `PSNavSaveButton`
/// so every sub-page matches.
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
        if large {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 8) { leading() }
                    Spacer()
                    HStack(spacing: 8) { trailing() }
                }
                .frame(minHeight: PSNavMetrics.button)

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
            .padding(.horizontal, 16)
            .padding(.top, 10)
        } else {
            PSNavBarRow {
                HStack(spacing: 8) { leading() }
                Text(title)
                    .font(PSFont.body(PSNavMetrics.title, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 8) { trailing() }
            }
            .frame(minHeight: PSNavMetrics.button)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// Sizes for compact (sub-page) nav bars and sheet headers: 1.5× the
/// original 32 pt buttons, 15 pt title and 14 pt text actions. The tab
/// screens' icon buttons and History's Select use the same button and text
/// sizes. Text sizes still scale with Dynamic Type through `PSFont`.
enum PSNavMetrics {
    /// Diameter of every round nav-bar button (back, close, "…", "+").
    static let button: CGFloat = 48
    /// Centred page title.
    static let title: CGFloat = 22
    /// Text actions: Edit, Cancel, Save, Close.
    static let text: CGFloat = 21
    /// Label of the filled Save capsule.
    static let saveLabel: CGFloat = 19.5
}

/// Lays out a compact nav bar: leading controls at the left edge, trailing
/// controls at the right edge, and the title centred on the whole bar. When
/// the controls on one side are too wide for that, the title is centred in
/// the space left between them instead (the rule `UINavigationBar` uses),
/// so it never runs under a button.
private struct PSNavBarRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let naturalWidth = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, sizes.count - 1))
        return CGSize(width: proposal.width ?? naturalWidth, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let leading = subviews[0], title = subviews[1], trailing = subviews[2]
        let leadingWidth = leading.sizeThatFits(.unspecified).width
        let trailingWidth = trailing.sizeThatFits(.unspecified).width
        leading.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        trailing.place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)

        let titleWidth = title.sizeThatFits(.unspecified).width
        let centredRoom = bounds.width - 2 * (max(leadingWidth, trailingWidth) + spacing)
        if titleWidth <= centredRoom {
            title.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                        proposal: ProposedViewSize(width: titleWidth, height: nil))
        } else {
            let minX = bounds.minX + leadingWidth + spacing
            let maxX = bounds.maxX - trailingWidth - spacing
            title.place(at: CGPoint(x: (minX + maxX) / 2, y: bounds.midY), anchor: .center,
                        proposal: ProposedViewSize(width: max(0, maxX - minX), height: nil))
        }
    }
}

/// Round chevron that leaves a detail page.
struct PSNavBackButton: View {
    let action: () -> Void

    var body: some View {
        PSIconBtn(systemName: "chevron.left", label: "Back", size: PSNavMetrics.button, action: action)
    }
}

/// Round ✕ that closes a sheet (About, Recipe).
struct PSNavCloseButton: View {
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: PSNavMetrics.button * 0.4, weight: .bold))
                .foregroundStyle(palette.inkSoft)
                .frame(width: PSNavMetrics.button, height: PSNavMetrics.button)
                .background(palette.surfaceAlt, in: Circle())
                .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

/// Text action in a sub-page bar or sheet header: "Edit", "Cancel", "Save",
/// "Close". Accent by default; `muted` for the quieter grey (Cancel while
/// editing, Close). The whole 44 pt-tall area is tappable.
struct PSNavTextButton: View {
    let title: String
    var weight: Font.Weight = .regular
    var muted: Bool = false
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PSFont.body(PSNavMetrics.text, weight: weight))
                .foregroundStyle(muted ? palette.inkSoft : palette.accent)
                .lineLimit(1)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Filled "Save" capsule shown while a detail page or recipe is being edited.
struct PSNavSaveButton: View {
    var enabled: Bool = true
    let action: () -> Void
    @Environment(\.psPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(PSFont.body(PSNavMetrics.saveLabel, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(palette.accent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
    }
}
