import SwiftUI
import SwiftData

/// Full-screen Add Hardware sheet, kind-aware (machine or grinder). Name uses
/// `OnbCombobox` driven by `HardwareCatalog`; selecting a suggestion auto-fills
/// the Brand field, but the user can also type a fully custom model. The
/// "Add a photo" card on this form is currently a non-interactive hint —
/// photos are attached afterwards from the Hardware detail edit flow.
struct HardwareAddForm: View {
    let kind: EquipmentKind
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @State private var name = ""
    @State private var brand = ""
    @State private var photoData: Data? = nil

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

                        labelGroup(kind == .machine ? "Espresso Machine" : "Grinder") {
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
        .environment(\.psPalette, PSPalette.resolve(for: scheme))
    }

    @ViewBuilder
    private func labelGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
    }

    private func save() {
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
        onSaved()
    }
}
