import SwiftUI
import SwiftData

/// Bean detail screen. Top-level Edit toggles every metadata field
/// (name, roaster, origin/process/roast, dates, photo, notes) into edit mode;
/// the recipe card has its own separate Edit flow so users can adjust a
/// recipe inline without entering the full edit. Delete cascades the bean's
/// shots — confirmation copy reflects the count.
struct BeanDetailView: View {
    let beanID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @Query private var beans: [Bean]
    private var bean: Bean? { beans.first }

    @State private var editing = false
    @State private var draft: Recipe = Recipe()
    @State private var showDeleteConfirm = false
    @State private var recipeEditingFlag: Bool = false

    @State private var dName = ""
    @State private var dRoaster = ""
    @State private var dRoast: Roast = .medium
    @State private var dProcess: BeanProcess = .washed
    @State private var dProcessOther = ""
    @State private var dSingleOrigin = false
    @State private var dRoastDate: Date = .now
    @State private var dPurchaseDate: Date = .now
    @State private var dNotes: String = ""
    @State private var dPhotoData: Data? = nil

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
                    PSIconBtn(systemName: "chevron.left", action: { dismiss() })
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

                if let bean {
                    contentBody(for: bean)
                } else {
                    Text("Bean not found")
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .psContentColumn()
        }
        .environment(\.psPalette, PSPalette.resolve(for: scheme))
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
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func bagPhoto(for bean: Bean) -> some View {
        let display: Data? = editing ? dPhotoData : bean.photoData
        PSPhotoThumb(data: display, label: "BAG PHOTO", radius: 14)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
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

        HStack(spacing: 6) {
            PSRoastBadge(level: bean.roast)
            chip(bean.processDisplay.uppercased(), accent: false)
            if bean.singleOrigin {
                chip("SINGLE ORIGIN", accent: true)
            }
        }
        .padding(.top, 10)

        section("Rating trend", topPad: 20) {
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

        section("Dates") {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Roast date") { PSValueText(text: PSFmt.shortDate(bean.roastDate), fontSize: 13) }
                    PSField(label: "Purchase date", last: true) { PSValueText(text: PSFmt.shortDate(bean.purchaseDate), fontSize: 13) }
                }
            }
        }

        if !bean.notes.isEmpty {
            section("Notes") {
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

        section("Identity", topPad: 18) {
            PSCard {
                VStack(spacing: 0) {
                    PSField(label: "Name") { PSTextInput(text: $dName, placeholder: "Black Gold") }
                    PSField(label: "Roaster", last: true) { PSTextInput(text: $dRoaster, placeholder: "Onyx Coffee Lab") }
                }
            }
        }

        section("Single Origin") {
            PSCard {
                HStack {
                    Text("Single Origin")
                        .font(PSFont.body(13))
                        .foregroundStyle(palette.inkSoft)
                    Spacer()
                    PSToggle(isOn: $dSingleOrigin)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }

        section("Process") {
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

        section("Roast Level") {
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

        section("Dates") {
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

        section("Photo") {
            PhotoEditCard(data: $dPhotoData, hint: "Snap the bag so it's easy to spot.")
        }

        section("Notes") {
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

    @ViewBuilder
    private func section<Content: View>(_ label: String, topPad: CGFloat = 18, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
        .padding(.top, topPad)
    }

    private func loadDraft(from bean: Bean) {
        dName = bean.name
        dRoaster = bean.roaster
        dRoast = bean.roast
        dProcess = bean.process
        dProcessOther = bean.processOther
        dSingleOrigin = bean.singleOrigin
        dRoastDate = bean.roastDate
        dPurchaseDate = bean.purchaseDate
        dNotes = bean.notes
        dPhotoData = bean.photoData
    }

    private func commitEdit(into bean: Bean) {
        bean.name = dName.isEmpty ? "Untitled" : dName
        bean.roaster = dRoaster
        bean.roast = dRoast
        bean.process = dProcess
        bean.processOther = dProcessOther
        bean.singleOrigin = dSingleOrigin
        bean.roastDate = dRoastDate
        bean.purchaseDate = dPurchaseDate
        bean.notes = dNotes
        bean.photoData = dPhotoData
        try? context.save()
    }
}
