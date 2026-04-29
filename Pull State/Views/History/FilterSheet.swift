import SwiftUI
import SwiftData

struct FilterSheet: View {
    @Binding var filterEx: Extraction?
    @Binding var filterRating: Int
    @Binding var filterBeanID: PersistentIdentifier?
    @Binding var filterMachineID: PersistentIdentifier?
    @Binding var filterGrinderID: PersistentIdentifier?
    @Binding var filterTags: Set<TastingTag>

    let beans: [Bean]
    let machines: [Equipment]
    let grinders: [Equipment]

    let onClose: () -> Void

    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PSDisplay("Filter shots", size: 20)
                Spacer()
                Button("Close", action: onClose)
                    .font(PSFont.body(14))
                    .foregroundStyle(palette.inkSoft)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PSSectionLabel("Extraction").padding(.leading, 4).padding(.top, 4).padding(.bottom, 8)
                    HStack(spacing: 6) {
                        ForEach(Extraction.allCases) { ex in
                            PSPill(
                                label: ex.rawValue,
                                active: filterEx == ex,
                                tone: tone(for: ex),
                                horizontalPadding: 8,
                                verticalPadding: 9,
                                fontSize: 12,
                                action: { filterEx = (filterEx == ex) ? nil : ex }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 14)

                    PSSectionLabel("Tasting notes").padding(.leading, 4).padding(.bottom, 8)
                    FlowLayout(spacing: 6, lineSpacing: 8) {
                        ForEach(TastingTag.allCases) { tag in
                            PSPill(
                                label: tag.label,
                                active: filterTags.contains(tag),
                                horizontalPadding: 10,
                                verticalPadding: 8,
                                fontSize: 12,
                                action: {
                                    if filterTags.contains(tag) { filterTags.remove(tag) } else { filterTags.insert(tag) }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 14)

                    PSSectionLabel("Min rating").padding(.leading, 4).padding(.bottom, 8)
                    HStack(spacing: 6) {
                        ForEach([0, 2, 3, 4, 5], id: \.self) { r in
                            PSPill(
                                label: r == 0 ? "Any" : "★\(r)+",
                                active: filterRating == r,
                                horizontalPadding: 8,
                                verticalPadding: 9,
                                fontSize: 12,
                                action: { filterRating = r }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 14)

                    PSSectionLabel("Beans").padding(.leading, 4).padding(.bottom, 8)
                    PSCard {
                        SelectRow(
                            options: [SelectOption(id: nil, label: "Any beans")] +
                                beans.map { SelectOption(id: $0.persistentModelID, label: $0.name, sub: "#\($0.bagNumber) · \($0.roaster)") },
                            selectedID: filterBeanID,
                            onPick: { filterBeanID = $0 },
                            last: true
                        )
                    }
                    .padding(.bottom, 14)

                    PSSectionLabel("Machine").padding(.leading, 4).padding(.bottom, 8)
                    PSCard {
                        SelectRow(
                            options: [SelectOption(id: nil, label: "Any machine")] +
                                machines.map { SelectOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                            selectedID: filterMachineID,
                            onPick: { filterMachineID = $0 },
                            last: true
                        )
                    }
                    .padding(.bottom, 14)

                    PSSectionLabel("Grinder").padding(.leading, 4).padding(.bottom, 8)
                    PSCard {
                        SelectRow(
                            options: [SelectOption(id: nil, label: "Any grinder")] +
                                grinders.map { SelectOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                            selectedID: filterGrinderID,
                            onPick: { filterGrinderID = $0 },
                            last: true
                        )
                    }
                    .padding(.bottom, 14)

                    HStack(spacing: 8) {
                        Button {
                            filterEx = nil
                            filterRating = 0
                            filterBeanID = nil
                            filterMachineID = nil
                            filterGrinderID = nil
                            filterTags = []
                        } label: {
                            Text("Clear all")
                                .font(PSFont.body(13, weight: .semibold))
                                .foregroundStyle(palette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(palette.lineStrong, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: onClose) {
                            Text("Apply")
                                .font(PSFont.body(13, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .psShadow(strong: true)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(2)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
        .psContentColumn()
    }

    private func tone(for ex: Extraction) -> PSPillTone {
        switch ex { case .sour: return .sour; case .perfect: return .perfect; case .bitter: return .bitter }
    }
}

struct SelectOption: Identifiable, Hashable {
    let id: PersistentIdentifier?
    let label: String
    var sub: String? = nil
}

struct SelectRow: View {
    let options: [SelectOption]
    let selectedID: PersistentIdentifier?
    let onPick: (PersistentIdentifier?) -> Void
    var last: Bool = false

    @Environment(\.psPalette) private var palette
    @State private var open = false

    private var current: SelectOption {
        options.first(where: { $0.id == selectedID }) ?? options[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(current.label)
                            .font(PSFont.body(14, weight: .semibold))
                            .foregroundStyle(palette.ink)
                        if let sub = current.sub, !sub.isEmpty {
                            Text(sub)
                                .font(PSFont.body(11))
                                .foregroundStyle(palette.inkSoft)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
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
                            .background(opt.id == selectedID ? palette.accentSoft : Color.clear)
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
        }
    }
}
