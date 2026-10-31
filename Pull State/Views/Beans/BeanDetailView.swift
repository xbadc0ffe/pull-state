import SwiftUI
import SwiftData

/// Bean detail screen. Top-level Edit toggles every metadata field
/// (name, roaster, origin/process/roast, dates, photo, notes) into edit mode;
/// the recipe card has its own separate Edit flow so users can adjust a
/// recipe inline without entering the full edit. Delete cascades the bean's
/// shots — confirmation copy reflects the count.
///
/// A quick-added bean has no roast or process yet; view mode shows a hint
/// instead, and edit mode leaves those pills unselected until one is picked.
/// Saving an edit clears `isPlaceholder`, so an "Unknown" bean the user has
/// adopted is never tidied away.
struct BeanDetailView: View {
    let beanID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.psPalette) private var palette

    @Query private var beans: [Bean]
    private var bean: Bean? { beans.first }

    @State private var editing = false
    @State private var draft: Recipe = Recipe()
    @State private var showDeleteConfirm = false
    @State private var recipeEditingFlag: Bool = false

    @State private var dName = ""
    @State private var dRoaster = ""
    /// nil while the bean has no roast / process set (quick-added beans).
    @State private var dRoast: Roast? = nil
    @State private var dProcess: BeanProcess? = nil
    @State private var dProcessOther = ""
    @State private var dSingleOrigin = false
    @State private var dRoastDate: Date = .now
    @State private var dPurchaseDate: Date = .now
    @State private var dNotes: String = ""
    @State private var dPhotoData: Data? = nil
    @State private var dTastingTags: Set<TastingTag> = []

    init(beanID: PersistentIdentifier) {
        self.beanID = beanID
        let id = beanID
        _beans = Query(filter: #Predicate<Bean> { $0.persistentModelID == id })
    }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: editing ? "Edit bean" : "Bean") {
                    PSIconBtn(systemName: "chevron.left", label: "Back", action: { dismiss() })
                } trailing: {
                    if let bean {
                        if editing {
                            HStack(spacing: 6) {
                                Button("Cancel") { editing = false }
                                    .foregroundStyle(palette.inkSoft)
                                    .font(PSFont.body(14))
                                    .buttonStyle(.plain)
                                Button("Save") {
                                    commitEdit(into: bean)
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
                                loadDraft(from: bean)
                                editing = true
                            }
                            .foregroundStyle(palette.accent)
                            .font(PSFont.body(14, weight: .semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
                .psContentColumn()

                if let bean {
                    contentBody(for: bean)
                } else {
                    Text("Bean not found")
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert("Delete \(bean?.name ?? "this bean")?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let bean {
                    context.delete(bean)
                    try? context.save()
                    dismiss()
                }
            }
        } message: {
            let count = bean?.shots.count ?? 0
            if count == 0 {
                Text("This bean will be removed.")
            } else {
                Text("All associated pulls will be deleted too. \(count) shot\(count == 1 ? "" : "s") will be removed.")
            }
        }
    }

    @ViewBuilder
    private func contentBody(for bean: Bean) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                bagPhoto(for: bean)
                    .padding(.bottom, 14)

                if editing {
                    editFields(for: bean)
                } else {
                    viewFields(for: bean)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .psContentColumn()
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func bagPhoto(for bean: Bean) -> some View {
        if editing {
            PSEditablePhotoHeader(data: $dPhotoData, label: "BAG PHOTO")
        } else {
            PSPhotoThumb(data: bean.photoData, label: "BAG PHOTO", radius: 14, hero: true)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func viewFields(for bean: Bean) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PSDisplay(bean.name, size: 26)
            Spacer()
            Text("BAG #\(bean.bagNumber)")
                .font(PSFont.mono(12))
                .foregroundStyle(palette.inkMuted)
        }
        Text(bean.roaster.isEmpty ? "—" : bean.roaster)
            .font(PSFont.body(13))
            .foregroundStyle(palette.inkSoft)
            .padding(.top, 4)
        Text("\(PSFmt.longDate(bean.roastDate)) · \(PSFmt.longDate(bean.purchaseDate))")
            .font(PSFont.body(11))
            .foregroundStyle(palette.inkMuted)
            .padding(.top, 2)

        if bean.roastIfSet == nil && bean.processIfSet == nil {
            Text("Roast and process not set yet. Tap Edit to add them.")
                .font(PSFont.body(11))
                .foregroundStyle(palette.inkMuted)
                .padding(.top, 8)
        }

        FlowLayout(spacing: 6, lineSpacing: 6, alignment: .leading) {
            if let roast = bean.roastIfSet {
                PSRoastBadge(level: roast)
            }
            if bean.processIfSet != nil {
                chip(bean.processDisplay.uppercased(), accent: false)
            }
            if bean.singleOrigin {
                chip("SINGLE ORIGIN", accent: true)
            }
            ForEach(bean.tastingTags) { tag in
                chip(tag.label.uppercased(), accent: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)

        PSSection("Rating trend", topPad: 20) {
            PSCard {
                if bean.ratingTrend.isEmpty {
                    Text("No shots yet")
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    RatingChart(points: bean.ratingTrend)
                        .padding(14)
                }
            }
        }

        if !bean.notes.isEmpty {
            PSSection("Notes", topPad: 18) {
                PSCard {
                    Text(bean.notes)
                        .font(PSFont.body(13.5))
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }

        HStack {
            PSSectionLabel("Recipe")
            Spacer()
            recipeEditButton(for: bean)
        }
        .padding(.top, 18)
        .padding(.bottom, 8)

        let editingRecipe = recipeEditingFlag
        RecipeBlock(
            recipe: editingRecipe ? $draft : .constant(bean.recipe),
            editing: editingRecipe
        )

        let shotCount = bean.shots.count
        let avg = bean.averageRating
        Text("\(shotCount) SHOTS · AVG \(avg.map { String(format: "%.1f", $0) } ?? "—")★")
            .font(PSFont.mono(10))
            .tracking(1)
            .foregroundStyle(palette.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
    }

    @ViewBuilder
    private func recipeEditButton(for bean: Bean) -> some View {
        if recipeEditingFlag {
            HStack(spacing: 6) {
                Button("Cancel") {
                    draft = bean.recipe
                    recipeEditingFlag = false
                }
                .font(PSFont.body(11, weight: .semibold))
                .foregroundStyle(palette.inkSoft)
                .buttonStyle(.plain)
                Button("Save") {
                    bean.recipe = draft
                    try? context.save()
                    recipeEditingFlag = false
                }
                .font(PSFont.body(11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(palette.accent, in: Capsule())
                .buttonStyle(.plain)
            }
        } else {
            Button {
                draft = bean.recipe
                recipeEditingFlag = true
            } label: {
                Text("Edit")
                    .font(PSFont.body(11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(palette.lineStrong, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func editFields(for bean: Bean) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PSDisplay(dName.isEmpty ? "—" : dName, size: 26)
            Spacer()
            Text("BAG #\(bean.bagNumber)")
                .font(PSFont.mono(12))
                .foregroundStyle(palette.inkMuted)
        }

        PSSection("Identity", topPad: 18) {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Name") { PSTextInput(text: $dName, placeholder: "Black Gold") }
                    PSField(label: "Roaster", last: true) { PSTextInput(text: $dRoaster, placeholder: "Onyx Coffee Lab") }
                }
            }
        }

        PSSection("Single Origin", topPad: 18) {
            PSCard {
                HStack {
                    Text("Single Origin")
                        .font(PSFont.body(13))
                        .foregroundStyle(palette.inkSoft)
                    Spacer()
                    PSToggle(isOn: $dSingleOrigin, label: "Single Origin")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }

        PSSection("Process", topPad: 18) {
            PSCard {
                VStack(alignment: .leading, spacing: 0) {
                    FlowLayout(spacing: 6, lineSpacing: 8) {
                        ForEach(BeanProcess.allCases) { p in
                            PSPill(
                                label: p.rawValue,
                                active: dProcess == p,
                                horizontalPadding: 12,
                                verticalPadding: 10,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) { dProcess = p }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if dProcess == .other {
                        Rectangle()
                            .fill(palette.line)
                            .frame(height: 0.5)
                        PSField(label: "Specify", last: true) {
                            PSTextInput(text: $dProcessOther, placeholder: "e.g. Anaerobic")
                        }
                    }
                }
            }
        }

        PSSection("Roast Level", topPad: 18) {
            PSCard {
                HStack(spacing: 6) {
                    ForEach(Roast.allCases) { r in
                        PSPill(label: r.rawValue, active: dRoast == r, horizontalPadding: 8, verticalPadding: 9, action: { dRoast = r })
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }

        PSSection("Tasting Notes", topPad: 18) {
            PSCard {
                FlowLayout(spacing: 6, alignment: .leading) {
                    ForEach(TastingTag.allCases) { tag in
                        PSPill(
                            label: tag.label,
                            active: dTastingTags.contains(tag),
                            action: {
                                if dTastingTags.contains(tag) {
                                    dTastingTags.remove(tag)
                                } else {
                                    dTastingTags.insert(tag)
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }

        PSSection("Dates", topPad: 18) {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Roast Date") {
                        DatePicker("", selection: $dRoastDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    PSField(label: "Purchase Date", last: true) {
                        DatePicker("", selection: $dPurchaseDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
            }
        }

        PSSection("Notes", topPad: 18) {
            PSCard {
                ZStack(alignment: .topLeading) {
                    if dNotes.isEmpty {
                        Text("Tasting notes from the bag…")
                            .font(PSFont.body(13.5))
                            .foregroundStyle(palette.inkMuted)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $dNotes)
                        .font(PSFont.body(13.5))
                        .foregroundStyle(palette.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 70)
                }
                .padding(8)
            }
        }

        deleteButton(for: bean)
            .padding(.top, 18)
    }

    @ViewBuilder
    private func deleteButton(for bean: Bean) -> some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete bean")
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
    }

    @ViewBuilder
    private func chip(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(PSFont.mono(9.5))
            .tracking(0.6)
            .foregroundStyle(accent ? palette.accentDeep : palette.inkSoft)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(accent ? palette.accentSoft : palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(accent ? palette.accent : palette.line, lineWidth: 0.5))
    }

    private func loadDraft(from bean: Bean) {
        dName = bean.name
        dRoaster = bean.roaster
        dRoast = bean.roastIfSet
        dProcess = bean.processIfSet
        dProcessOther = bean.processOther
        dSingleOrigin = bean.singleOrigin
        dRoastDate = bean.roastDate
        dPurchaseDate = bean.purchaseDate
        dNotes = bean.notes
        dPhotoData = bean.photoData
        dTastingTags = Set(bean.tastingTags)
    }

    private func commitEdit(into bean: Bean) {
        let trimmedName = dName.trimmingCharacters(in: .whitespacesAndNewlines)
        bean.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        bean.roaster = dRoaster.trimmingCharacters(in: .whitespacesAndNewlines)
        // Left unset unless the user picked one.
        if let dRoast { bean.roast = dRoast }
        if let dProcess { bean.process = dProcess }
        bean.processOther = dProcessOther
        bean.isPlaceholder = false
        bean.singleOrigin = dSingleOrigin
        bean.roastDate = dRoastDate
        bean.purchaseDate = dPurchaseDate
        bean.notes = dNotes
        bean.photoData = dPhotoData
        bean.tastingTags = Array(dTastingTags)
        try? context.save()
    }
}
