import SwiftUI
import SwiftData

struct BeanAddForm: View {
    @Bindable var settings: AppSettings
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @Query private var existingBeans: [Bean]

    @State private var name = ""
    @State private var roaster = ""
    @State private var singleOrigin = true
    @State private var process: BeanProcess = .washed
    @State private var processOther = ""
    @State private var roast: Roast = .medium
    @State private var roastDate: Date = .now
    @State private var purchaseDate: Date = .now
    @State private var notes = ""
    @State private var recipe: Recipe = Recipe()
    @State private var photoData: Data? = nil
    @State private var preloadedFromBeanID: PersistentIdentifier? = nil

    private var nextBag: Int { settings.nextBagNumber }

    private var matchingBean: Bean? {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        let r = roaster.trimmingCharacters(in: .whitespaces).lowercased()
        guard !n.isEmpty, !r.isEmpty else { return nil }
        return existingBeans
            .filter {
                $0.name.trimmingCharacters(in: .whitespaces).lowercased() == n
                    && $0.roaster.trimmingCharacters(in: .whitespaces).lowercased() == r
            }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    private func preloadFromMatchingBeanIfNeeded() {
        guard let match = matchingBean,
              match.persistentModelID != preloadedFromBeanID else { return }
        recipe = match.recipe
        preloadedFromBeanID = match.persistentModelID
    }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: "Add Bean") {
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
                    VStack(alignment: .leading, spacing: 18) {
                        Text("BAG #\(nextBag) · AUTO")
                            .font(PSFont.mono(11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(palette.accentDeep)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(palette.accent, lineWidth: 0.5)
                            )

                        labelGroup("Identity") {
                            PSCard {
                                VStack(spacing: 0) {
                                    PSField(label: "Bean Name") {
                                        PSTextInput(text: $name, placeholder: "Black Gold", alignment: .trailing)
                                    }
                                    PSField(label: "Roaster", last: true) {
                                        PSTextInput(text: $roaster, placeholder: "Onyx Coffee Lab", alignment: .trailing)
                                    }
                                }
                            }
                        }

                        labelGroup("Single Origin") {
                            PSCard {
                                HStack {
                                    Text("Single Origin")
                                        .font(PSFont.body(13))
                                        .foregroundStyle(palette.inkSoft)
                                    Spacer()
                                    PSToggle(isOn: $singleOrigin)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                        }

                        labelGroup("Process") {
                            PSCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    FlowLayout(spacing: 6, lineSpacing: 8) {
                                        ForEach(BeanProcess.allCases) { p in
                                            PSPill(
                                                label: p.rawValue,
                                                active: process == p,
                                                horizontalPadding: 12,
                                                verticalPadding: 10,
                                                action: {
                                                    withAnimation(.easeInOut(duration: 0.2)) { process = p }
                                                }
                                            )
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)

                                    if process == .other {
                                        Rectangle()
                                            .fill(palette.line)
                                            .frame(height: 0.5)
                                        PSField(label: "Specify process", last: true) {
                                            PSTextInput(text: $processOther, placeholder: "e.g. Anaerobic", alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }

                        labelGroup("Roast Level") {
                            PSCard {
                                HStack(spacing: 6) {
                                    ForEach(Roast.allCases) { r in
                                        PSPill(
                                            label: r.rawValue,
                                            active: roast == r,
                                            horizontalPadding: 8,
                                            verticalPadding: 9,
                                            action: { roast = r }
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                        }

                        labelGroup("Dates") {
                            PSCard {
                                VStack(spacing: 0) {
                                    PSField(label: "Roast Date") {
                                        DatePicker("", selection: $roastDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .accentColor(palette.accent)
                                    }
                                    PSField(label: "Purchase Date", last: true) {
                                        DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .accentColor(palette.accent)
                                    }
                                }
                            }
                        }

                        labelGroup("Photo") {
                            PhotoEditCard(data: $photoData, hint: "Helps you spot the bag in your shelf")
                        }

                        labelGroup("Notes") {
                            PSCard {
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Tasting notes from the bag…")
                                            .font(PSFont.body(13.5))
                                            .foregroundStyle(palette.inkMuted)
                                            .padding(.horizontal, 4)
                                            .padding(.top, 8)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $notes)
                                        .font(PSFont.body(13.5))
                                        .foregroundStyle(palette.ink)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 70)
                                }
                                .padding(8)
                            }
                        }

                        labelGroup("Recipe") {
                            RecipeBlock(recipe: $recipe, editing: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .psContentColumn()
        }
        .environment(\.psPalette, PSPalette.resolve(for: scheme))
        .onChange(of: name) { _, _ in preloadFromMatchingBeanIfNeeded() }
        .onChange(of: roaster) { _, _ in preloadFromMatchingBeanIfNeeded() }
    }

    @ViewBuilder
    private func labelGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
    }

    private func save() {
        let bean = Bean(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : name,
            bagNumber: nextBag,
            roaster: roaster,
            singleOrigin: singleOrigin,
            process: process,
            processOther: processOther,
            roast: roast,
            roastDate: roastDate,
            purchaseDate: purchaseDate,
            notes: notes,
            recipe: recipe,
            photoData: photoData
        )
        context.insert(bean)
        settings.nextBagNumber = nextBag + 1
        try? context.save()
        onSaved()
    }
}
