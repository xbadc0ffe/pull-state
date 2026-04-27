import SwiftUI
import SwiftData

struct HardwareAddForm: View {
    let kind: EquipmentKind
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @State private var name = ""
    @State private var brand = ""

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        labelGroup(kind == .machine ? "Espresso Machine" : "Grinder") {
                            PSCard {
                                VStack(spacing: 0) {
                                    PSField(label: "Name") {
                                        PSTextInput(text: $name, placeholder: kind.examplePlaceholder, alignment: .trailing)
                                    }
                                    PSField(label: "Brand", last: true) {
                                        PSTextInput(text: $brand, placeholder: kind.exampleBrandPlaceholder, alignment: .trailing)
                                    }
                                }
                            }
                        }

                        labelGroup("Photo") {
                            PSCard {
                                HStack(spacing: 12) {
                                    PSPlaceholder(label: "ADD", radius: 10)
                                        .frame(width: 56, height: 56)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Add a photo")
                                            .font(PSFont.body(13, weight: .semibold))
                                            .foregroundStyle(palette.ink)
                                        Text("Optional · helps when picking on Log")
                                            .font(PSFont.body(11))
                                            .foregroundStyle(palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "camera")
                                        .font(.system(size: 22))
                                        .foregroundStyle(palette.accent)
                                }
                                .padding(14)
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
                }
                .scrollIndicators(.hidden)
            }
            .psContentColumn()
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
            kind: kind
        )
        context.insert(item)
        try? context.save()
        onSaved()
    }
}
