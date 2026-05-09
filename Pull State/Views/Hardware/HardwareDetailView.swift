import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Hardware detail screen — read mode shows photo, name, brand, live shot
/// count, and date added. Edit mode allows name / brand / photo changes.
/// Delete uses the `.nullify` rule so historical shots survive the deletion.
struct HardwareDetailView: View {
    let hardwareID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @Query private var equipment: [Equipment]
    private var item: Equipment? { equipment.first }

    @State private var editing = false
    @State private var showDeleteConfirm = false

    @State private var dName: String = ""
    @State private var dBrand: String = ""
    @State private var dPhotoData: Data? = nil

    init(hardwareID: PersistentIdentifier) {
        self.hardwareID = hardwareID
        let id = hardwareID
        _equipment = Query(filter: #Predicate<Equipment> { $0.persistentModelID == id })
    }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: editing ? "Edit \(item?.kind.singular.lowercased() ?? "item")" : (item?.kind.singular ?? "Hardware")) {
                    PSIconBtn(systemName: "chevron.left", action: { dismiss() })
                } trailing: {
                    if let item {
                        if editing {
                            HStack(spacing: 6) {
                                Button("Cancel") { editing = false }
                                    .foregroundStyle(palette.inkSoft)
                                    .font(PSFont.body(14))
                                    .buttonStyle(.plain)
                                Button("Save") {
                                    commit(into: item)
                                    editing = false
                                }
                                .foregroundStyle(.white)
                                .font(PSFont.body(13, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(palette.accent, in: Capsule())
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button("Edit") {
                                load(from: item)
                                editing = true
                            }
                            .foregroundStyle(palette.accent)
                            .font(PSFont.body(14, weight: .semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
                .psContentColumn()

                if let item {
                    contentBody(for: item)
                } else {
                    Text("Hardware not found")
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .environment(\.psPalette, PSPalette.resolve(for: scheme))
        .alert("Delete \(item?.name ?? "this item")?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let item {
                    context.delete(item)
                    try? context.save()
                    dismiss()
                }
            }
        } message: {
            Text("Past shots logged on this \(item?.kind.singular.lowercased() ?? "item") will stay in your history but will no longer reference it.")
        }
    }

    @ViewBuilder
    private func contentBody(for item: Equipment) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                photoView(for: item)

                if editing {
                    editFields(for: item)
                } else {
                    viewFields(for: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .psContentColumn()
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func photoView(for item: Equipment) -> some View {
        if editing {
            PSEditablePhotoHeader(data: $dPhotoData, label: item.kind.singular.uppercased())
        } else {
            PSPhotoThumb(data: item.photoData, label: item.kind.singular.uppercased(), radius: 14)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func viewFields(for item: Equipment) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PSDisplay(item.name, size: 26)
            Spacer()
        }
        Text(item.brand.isEmpty ? "—" : item.brand)
            .font(PSFont.body(13))
            .foregroundStyle(palette.inkSoft)

        section("Stats") {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Shots pulled") {
                        PSValueText(text: "\(item.shotCount)", fontSize: 13.5)
                    }
                    PSField(label: "Date added", last: true) {
                        PSValueText(text: PSFmt.shortDate(item.createdAt), fontSize: 13)
                    }
                }
            }
        }

        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete \(item.kind.singular.lowercased())")
                    .font(PSFont.body(14, weight: .bold))
                    .tracking(0.4)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(palette.bad, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .psShadow(strong: true)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func editFields(for item: Equipment) -> some View {
        section("Identity") {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Name") {
                        PSTextInput(text: $dName, placeholder: item.kind.examplePlaceholder, alignment: .trailing)
                    }
                    PSField(label: "Brand", last: true) {
                        PSTextInput(text: $dBrand, placeholder: item.kind.exampleBrandPlaceholder, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
    }

    private func load(from item: Equipment) {
        dName = item.name
        dBrand = item.brand
        dPhotoData = item.photoData
    }

    private func commit(into item: Equipment) {
        item.name = dName.isEmpty ? item.kind.defaultName : dName
        item.brand = dBrand
        item.photoData = dPhotoData
        try? context.save()
    }
}
