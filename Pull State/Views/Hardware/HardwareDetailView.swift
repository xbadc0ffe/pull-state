import SwiftUI
import SwiftData

struct HardwareDetailView: View {
    let hardwareID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @Query private var equipment: [Equipment]
    private var item: Equipment? { equipment.first { $0.persistentModelID == hardwareID } }

    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: item?.kind.singular ?? "Hardware") {
                    PSIconBtn(systemName: "chevron.left", action: { dismiss() })
                } trailing: { EmptyView() }

                if let item {
                    contentBody(for: item)
                } else {
                    Text("Hardware not found")
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .psContentColumn()
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
                PSPlaceholder(label: item.kind.singular.uppercased(), radius: 14)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4.0/3.0, contentMode: .fit)

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
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
    }
}
