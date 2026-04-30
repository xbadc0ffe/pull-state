import SwiftUI
import SwiftData

/// One choice in a `PickerRow`'s expanded list, identified by SwiftData's
/// `PersistentIdentifier`.
struct PickerOption: Identifiable, Hashable {
    let id: PersistentIdentifier
    let label: String
    let sub: String?
}

/// Inline-expanding picker row used by the Log screen and Shot edit's Source
/// card. The row collapses by default and reveals its options below when
/// tapped — keeps the entire shot setup on one scroll without modal hops.
struct PickerRow: View {
    let label: String
    let value: String
    let sub: String?
    let options: [PickerOption]
    let selectedID: PersistentIdentifier?
    let onPick: (PersistentIdentifier) -> Void
    var last: Bool = false

    @Environment(\.psPalette) private var palette
    @State private var open = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label.uppercased())
                            .font(PSFont.mono(9.5, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(palette.inkMuted)
                        Text(value)
                            .font(PSFont.display(17, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        if let sub, !sub.isEmpty {
                            Text(sub)
                                .font(PSFont.body(11))
                                .foregroundStyle(palette.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.inkMuted)
                        .rotationEffect(open ? .degrees(90) : .degrees(0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 0) {
                    ForEach(options) { opt in
                        Button {
                            onPick(opt.id)
                            withAnimation(.easeInOut(duration: 0.18)) { open = false }
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(opt.label)
                                    .font(PSFont.body(13, weight: .semibold))
                                    .foregroundStyle(palette.ink)
                                if let sub = opt.sub, !sub.isEmpty {
                                    Text(sub)
                                        .font(PSFont.body(11))
                                        .foregroundStyle(palette.inkSoft)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 22)
                            .padding(.trailing, 14)
                            .padding(.vertical, 10)
                            .overlay(
                                Rectangle().fill(palette.line).frame(height: 0.5),
                                alignment: .top
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(palette.surfaceAlt)
            }

            if !last && !open {
                Rectangle().fill(palette.line).frame(height: 0.5)
            } else if !last && open {
                Rectangle().fill(palette.line).frame(height: 0.5)
            }
        }
    }
}
