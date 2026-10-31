import SwiftUI
import SwiftData

/// One choice in a `PickerRow`'s expanded list, identified by SwiftData's
/// `PersistentIdentifier`. `photoData` is shown as a leading thumbnail when
/// the parent `PickerRow` opts into thumbnails.
struct PickerOption: Identifiable, Hashable {
    let id: PersistentIdentifier
    let label: String
    let sub: String?
    var photoData: Data? = nil
}

/// A choice listed above a `PickerRow`'s model options that isn't a model —
/// "None" in Shot edit, "Keep current" in History's bulk edit.
struct PickerExtraChoice: Identifiable {
    let label: String
    let selected: Bool
    let action: () -> Void

    var id: String { label }
}

/// Inline-expanding picker row used by the Log screen, Shot edit's Source
/// card and History's bulk edit. The row collapses by default and reveals its
/// options below when tapped — keeps the entire shot setup on one scroll
/// without modal hops.
///
/// With `onAdd`, the list ends in a "+ New …" row; and when there is nothing
/// to choose from, tapping the row itself calls `onAdd` (opens the add form).
/// `unset` styles the value as missing (accent text, "+" badge instead of a
/// photo); `pulse` adds the repeating glow the Log screen uses for gear that
/// hasn't been set up yet.
struct PickerRow: View {
    let label: String
    let value: String
    let sub: String?
    let options: [PickerOption]
    let selectedID: PersistentIdentifier?
    let onPick: (PersistentIdentifier) -> Void
    var last: Bool = false
    var photoData: Data? = nil
    var showThumbnails: Bool = false
    var extraChoices: [PickerExtraChoice] = []
    var addLabel: String? = nil
    var onAdd: (() -> Void)? = nil
    var unset: Bool = false
    var pulse: Bool = false

    @Environment(\.psPalette) private var palette
    @State private var open = false

    /// Nothing to pick: tapping the row goes straight to the add form.
    private var addsDirectly: Bool {
        options.isEmpty && extraChoices.isEmpty && onAdd != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if addsDirectly, let onAdd {
                    onAdd()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { open.toggle() }
                }
            } label: {
                HStack(spacing: 12) {
                    if showThumbnails {
                        if unset {
                            addBadge
                                .frame(width: 44, height: 44)
                        } else {
                            PSPhotoThumb(data: photoData, label: label.uppercased(), radius: 8)
                                .frame(width: 44, height: 44)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label.uppercased())
                            .font(PSFont.mono(9.5, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(palette.inkMuted)
                        Text(value)
                            .font(PSFont.display(17, weight: .semibold))
                            .foregroundStyle(unset ? palette.accentDeep : palette.ink)
                            .lineLimit(1)
                        if let sub, !sub.isEmpty {
                            Text(sub)
                                .font(PSFont.body(11))
                                .foregroundStyle(palette.inkSoft)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: addsDirectly ? "plus" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(addsDirectly ? palette.accent : palette.inkMuted)
                        .rotationEffect(open ? .degrees(90) : .degrees(0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    if pulse {
                        PSAttentionGlow(cornerRadius: 12)
                            .padding(4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(addsDirectly ? "Adds a new \(label.lowercased())" : "")

            if open {
                VStack(spacing: 0) {
                    ForEach(extraChoices) { choice in
                        choiceRow(selected: choice.selected) {
                            choice.action()
                            close()
                        } content: {
                            Text(choice.label)
                                .font(PSFont.body(13, weight: .semibold))
                                .foregroundStyle(palette.ink)
                        }
                    }
                    ForEach(options) { opt in
                        choiceRow(selected: opt.id == selectedID) {
                            onPick(opt.id)
                            close()
                        } content: {
                            if showThumbnails {
                                PSPhotoThumb(data: opt.photoData, label: nil, radius: 6)
                                    .frame(width: 32, height: 32)
                            }
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
                        }
                    }
                    if let onAdd, let addLabel {
                        choiceRow(selected: false) {
                            close()
                            onAdd()
                        } content: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.accent)
                                .frame(width: showThumbnails ? 32 : nil)
                            Text(addLabel)
                                .font(PSFont.body(13, weight: .semibold))
                                .foregroundStyle(palette.accentDeep)
                        }
                    }
                }
                .background(palette.surfaceAlt)
            }

            if !last {
                Rectangle().fill(palette.line).frame(height: 0.5)
            }
        }
    }

    /// The "+" square that stands in for the photo while nothing is set.
    private var addBadge: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(palette.accentSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.accent)
            )
            .accessibilityHidden(true)
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.18)) { open = false }
    }

    /// One row of the expanded list, with a checkmark when it is the current
    /// choice.
    private func choiceRow<Content: View>(
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content()
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.accentDeep)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, showThumbnails ? 14 : 22)
            .padding(.trailing, 14)
            .padding(.vertical, showThumbnails ? 8 : 10)
            .overlay(
                Rectangle().fill(palette.line).frame(height: 0.5),
                alignment: .top
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
