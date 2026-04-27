import SwiftUI
import SwiftData

struct BeanAddForm: View {
    @Bindable var settings: AppSettings
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @State private var name = ""
    @State private var roaster = ""
    @State private var singleOrigin = true
    @State private var process: BeanProcess = .washed
    @State private var processOther = ""
    @State private var roast: Roast = .medium
    @State private var roastDate: Date = .now
    @State private var purchaseDate: Date = .now
    @State private var notes = ""
    @State private var recipe: Recipe = .default

    private var nextBag: Int { settings.nextBagNumber }

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
                    VStack(alignment: .leading, spacing: 14) {
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
                            FlowLayout(spacing: 6) {
                                ForEach(BeanProcess.allCases) { p in
                                    PSPill(
                                        label: p.rawValue,
                                        active: process == p,
                                        horizontalPadding: 12,
                                        verticalPadding: 9,
                                        action: { process = p }
                                    )
                                }
                            }
                            if process == .other {
                                PSCard {
                                    PSField(label: "Specify process", last: true) {
                                        PSTextInput(text: $processOther, placeholder: "e.g. Anaerobic", alignment: .trailing)
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }

                        labelGroup("Roast Level") {
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
                            PSCard {
                                HStack(spacing: 12) {
                                    PSPlaceholder(label: "ADD", radius: 10)
                                        .frame(width: 56, height: 56)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Add a photo")
                                            .font(PSFont.body(13, weight: .semibold))
                                            .foregroundStyle(palette.ink)
                                        Text("Helps you spot the bag in your shelf")
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
            recipe: recipe
        )
        context.insert(bean)
        settings.nextBagNumber = nextBag + 1
        try? context.save()
        onSaved()
    }
}
