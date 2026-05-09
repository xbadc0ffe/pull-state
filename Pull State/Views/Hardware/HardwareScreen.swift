import SwiftUI
import SwiftData

/// Hardware tab — two stacked sections (Espresso Machines, Grinders) with a
/// per-section "+ Add" button. Cards show the live shot count via the inverse
/// SwiftData relationship, so the count updates without a denormalized field.
struct HardwareScreen: View {
    let onAdd: (EquipmentKind) -> Void
    let onShowAbout: () -> Void

    @Environment(\.psPalette) private var palette
    @Query(sort: \Equipment.createdAt) private var equipment: [Equipment]

    private var machines: [Equipment] { equipment.filter { $0.kind == .machine } }
    private var grinders: [Equipment] { equipment.filter { $0.kind == .grinder } }

    var body: some View {
        VStack(spacing: 0) {
            PSNavBar(title: "Hardware", large: true) {
                EmptyView()
            } trailing: {
                PSIconBtn(systemName: "ellipsis", action: onShowAbout)
            }
            .psContentColumn()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("Espresso Machines", kind: .machine, items: machines)
                    section("Grinders", kind: .grinder, items: grinders)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
                .psContentColumn()
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func section(_ title: String, kind: EquipmentKind, items: [Equipment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PSDisplay(title, size: 20)
                Spacer()
                Button { onAdd(kind) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                            .font(PSFont.body(12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(palette.accentDeep)
                    .background(palette.accentSoft, in: Capsule())
                    .overlay(Capsule().strokeBorder(palette.accent, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 4)

            if items.isEmpty {
                Text("None yet — tap Add to log your first.")
                    .font(PSFont.body(12))
                    .foregroundStyle(palette.inkMuted)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: NavRoute.hardware(item.persistentModelID)) {
                            HardwareCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HardwareCard: View {
    let item: Equipment
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSCard(soft: true) {
            HStack(spacing: 12) {
                PSPhotoThumb(data: item.photoData, label: "HARDWARE", radius: 10)
                    .frame(width: 78, height: 78)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(PSFont.display(18, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(item.brand)
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkSoft)
                        .padding(.bottom, 6)
                    HStack(spacing: 6) {
                        Text("\(item.shotCount)")
                            .font(PSFont.mono(11, weight: .bold))
                            .foregroundStyle(palette.accent)
                        Text("SHOTS")
                            .font(PSFont.mono(9))
                            .tracking(1)
                            .foregroundStyle(palette.inkMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(palette.line, lineWidth: 0.5))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(12)
        }
    }
}
