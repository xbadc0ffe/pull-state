import SwiftUI
import SwiftData

/// Full-screen Add Hardware sheet, kind-aware (machine or grinder). Name uses
/// `OnbCombobox` driven by `HardwareCatalog`; selecting a suggestion auto-fills
/// the Brand field, but the user can also type a fully custom model. The
/// photo header at the top goes through the standard `PSPhotoSourceMenu` →
/// crop flow and is persisted as `Equipment.photoData` on save.
///
/// After saving, if any logged shots have no machine (or grinder) yet, the
/// form offers to attach the new item to all of them before closing — that is
/// how shots logged before any hardware existed get filled in. History's bulk
/// edit passes `offerBackfill: false`, since the user is already choosing
/// which shots to change. `onSaved` receives the new item so the opener can
/// select it.
struct HardwareAddForm: View {
    let kind: EquipmentKind
    var offerBackfill: Bool = true
    let onCancel: () -> Void
    let onSaved: (Equipment) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette

    @State private var name = ""
    @State private var brand = ""
    @State private var photoData: Data? = nil
    @State private var savedItem: Equipment? = nil
    @State private var backfillCount = 0
    @State private var showBackfill = false

    private var isMachine: Bool { kind == .machine }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: kind.addLabel) {
                    Button("Cancel", action: onCancel)
                        .font(PSFont.body(14))
                        .foregroundStyle(palette.accent)
                        .buttonStyle(.plain)
                } trailing: {
                    Button("Save", action: save)
                        .font(PSFont.body(14, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .buttonStyle(.plain)
                }
                .psContentColumn()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PSEditablePhotoHeader(data: $photoData, label: kind.singular.uppercased())

                        PSSection(kind == .machine ? "Espresso Machine" : "Grinder") {
                            VStack(alignment: .leading, spacing: 12) {
                                OnbCombobox(
                                    label: "Name",
                                    text: $name,
                                    placeholder: "Search or type a model…",
                                    options: HardwareCatalog.entries(for: kind).map(\.name),
                                    onSelect: { picked in
                                        if let b = HardwareCatalog.brand(forName: picked, kind: kind) {
                                            brand = b
                                        }
                                    }
                                )
                                OnbField(label: "Brand", text: $brand, placeholder: "e.g. \(kind.exampleBrandPlaceholder)")
                            }
                        }

                        Text(isMachine
                             ? "New machines start at 0 shots. Pulling shots on the Log tab will increment this automatically."
                             : "Grinder shot counts track how many shots have run through this burr set.")
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .psContentColumn()
                }
                .scrollIndicators(.hidden)
            }
        }
        .alert("Use \(savedItem?.name ?? kind.singular) for past shots?", isPresented: $showBackfill) {
            Button("Assign to \(backfillCount) shot\(backfillCount == 1 ? "" : "s")") {
                if let savedItem {
                    ShotReassignment.backfill(savedItem, in: context)
                }
                finish()
            }
            Button("Not now", role: .cancel) { finish() }
        } message: {
            Text("\(backfillCount) logged shot\(backfillCount == 1 ? " has" : "s have") no \(kind.singular.lowercased()) yet. You can still change any shot later.")
        }
    }

    private func save() {
        // The backfill alert keeps the form on screen; never insert twice.
        guard savedItem == nil else { return }
        let finalName = name.trimmingCharacters(in: .whitespaces)
        let finalBrand = brand.trimmingCharacters(in: .whitespaces)
        let item = Equipment(
            name: finalName.isEmpty ? kind.defaultName : finalName,
            brand: finalBrand,
            kind: kind,
            photoData: photoData
        )
        context.insert(item)
        try? context.save()
        savedItem = item

        if offerBackfill {
            let missing = ShotReassignment.shotsMissing(kind, in: context).count
            if missing > 0 {
                backfillCount = missing
                showBackfill = true
                return
            }
        }
        finish()
    }

    private func finish() {
        if let savedItem { onSaved(savedItem) }
    }
}
