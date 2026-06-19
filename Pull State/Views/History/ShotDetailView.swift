import SwiftUI
import SwiftData

struct ShotDetailView: View {
    let shotID: PersistentIdentifier
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.psTempUnit) private var tempUnit

    @Query private var shots: [Shot]
    @Query(sort: \Bean.bagNumber, order: .reverse) private var beans: [Bean]
    @Query(sort: \Equipment.createdAt) private var equipment: [Equipment]
    private var shot: Shot? { shots.first }

    @State private var editing = false
    @State private var showDeleteConfirm = false

    // Edit-mode draft
    @State private var dDate: Date = .now
    @State private var dDose: Double = 18
    @State private var dYield: Double = 38
    @State private var dWaterTemp: Double = 93
    @State private var dPressure: Double = 9
    @State private var dPreInfPressure: Double = 1
    @State private var dPre: Double = 0
    @State private var dPull: Double = 0
    @State private var dRating: Int = 0
    @State private var dNotes: String = ""
    @State private var dExtraction: Extraction? = nil
    @State private var dTags: Set<TastingTag> = []
    @State private var dBeanID: PersistentIdentifier? = nil
    @State private var dMachineID: PersistentIdentifier? = nil
    @State private var dGrinderID: PersistentIdentifier? = nil
    @State private var dPhotoData: Data? = nil
    @State private var dPaperFilter: Bool = false

    init(shotID: PersistentIdentifier) {
        self.shotID = shotID
        let id = shotID
        _shots = Query(filter: #Predicate<Shot> { $0.persistentModelID == id })
    }

    private var machines: [Equipment] { equipment.filter { $0.kind == .machine } }
    private var grinders: [Equipment] { equipment.filter { $0.kind == .grinder } }

    var body: some View {
        ZStack {
            PSPageBackground()
            VStack(spacing: 0) {
                PSNavBar(title: editing ? "Edit shot" : "Shot detail") {
                    PSIconBtn(systemName: "chevron.left", action: { dismiss() })
                } trailing: {
                    if let shot {
                        if editing {
                            HStack(spacing: 6) {
                                Button("Cancel") {
                                    editing = false
                                }
                                .foregroundStyle(palette.inkSoft)
                                .font(PSFont.body(14))
                                .buttonStyle(.plain)
                                Button("Save") {
                                    commitEdit(into: shot)
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
                                loadDraft(from: shot)
                                editing = true
                            }
                            .foregroundStyle(palette.accent)
                            .font(PSFont.body(14, weight: .semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
                .psContentColumn()

                if let shot {
                    contentBody(for: shot)
                } else {
                    Text("Shot not found")
                        .foregroundStyle(palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .environment(\.psPalette, PSPalette.resolve(for: scheme))
        .alert("Delete this shot?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let shot {
                    context.delete(shot)
                    try? context.save()
                    dismiss()
                }
            }
        } message: {
            Text("This shot will be permanently removed.")
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private func contentBody(for shot: Shot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                photoView(for: shot)

                HStack(alignment: .firstTextBaseline) {
                    PSDisplay(shot.bean?.name ?? "Unknown", size: 24)
                    Spacer()
                    Text("#\(shot.bean?.bagNumber ?? 0)")
                        .font(PSFont.mono(12))
                        .foregroundStyle(palette.inkMuted)
                }
                HStack(spacing: 10) {
                    if editing {
                        PSStars(value: $dRating, size: 18)
                    } else {
                        PSStars(staticValue: shot.rating, size: 18)
                    }
                    if let ex = (editing ? dExtraction : shot.extraction) {
                        PSPill(label: ex.rawValue, active: true, tone: tone(ex), horizontalPadding: 10, verticalPadding: 5)
                    }
                }

                if editing {
                    sourcePickers
                    extractionPicker
                    tagsPicker
                    numbersEditableCard
                    dateEditCard(for: shot)
                    notesEditor
                    deleteButton
                } else {
                    section("Numbers") {
                        PSCard {
                            VStack(spacing: 0) {
                                PSField(label: "Dose") { PSValueText(text: String(format: "%.1fg", shot.dose), fontSize: 13.5) }
                                PSField(label: "Yield", suffix: String(format: "%.1fg", shot.yield)) { PSValueText(text: String(format: "1:%.2f", shot.ratio), fontSize: 13.5) }
                                PSField(label: "Grind") { PSValueText(text: shot.grindSetting.isEmpty ? "—" : shot.grindSetting, fontSize: 13.5) }
                                PSField(label: "Water Temp") { PSValueText(text: formattedTemp(shot.waterTemp), fontSize: 13.5) }
                                PSField(label: "Pre-Infusion Pressure") { PSValueText(text: "\(formattedPressure(shot.preInfPressure)) bar", fontSize: 13.5) }
                                PSField(label: "Pre-Infusion Time") { PSValueText(text: String(format: "%.1fs", shot.preInfusion), fontSize: 13.5) }
                                PSField(label: "Pull Pressure") { PSValueText(text: "\(formattedPressure(shot.pressure)) bar", fontSize: 13.5) }
                                if shot.usedPaperFilter {
                                    PSField(label: "Pull Time") { PSValueText(text: String(format: "%.1fs", shot.pull), fontSize: 13.5) }
                                    PSField(label: "Paper Filter", last: true) { PSValueText(text: "Yes", fontSize: 13.5) }
                                } else {
                                    PSField(label: "Pull Time", last: true) { PSValueText(text: String(format: "%.1fs", shot.pull), fontSize: 13.5) }
                                }
                            }
                        }
                    }

                    section("Hardware") {
                        PSCard {
                            VStack(spacing: 0) {
                                PSField(label: "Machine") { PSValueText(text: shot.machine?.name ?? "—", fontSize: 13.5) }
                                PSField(label: "Grinder", last: true) { PSValueText(text: shot.grinder?.name ?? "—", fontSize: 13.5) }
                            }
                        }
                    }

                    section("Tasting notes") {
                        if shot.tags.isEmpty {
                            Text("No tags")
                                .font(PSFont.body(12))
                                .foregroundStyle(palette.inkMuted)
                        } else {
                            FlowLayout(spacing: 6) {
                                ForEach(shot.tags) { PSPill(label: $0.label, active: true) }
                            }
                        }
                    }

                    if !shot.notes.isEmpty {
                        section("Notes") {
                            PSCard {
                                Text(shot.notes)
                                    .font(PSFont.body(13.5))
                                    .foregroundStyle(palette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                        }
                    }

                    Text(PSFmt.detailDate(shot.date))
                        .font(PSFont.mono(10))
                        .tracking(1)
                        .foregroundStyle(palette.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .psContentColumn()
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func photoView(for shot: Shot) -> some View {
        if editing {
            PSEditablePhotoHeader(data: $dPhotoData, label: "SHOT PHOTO")
        } else {
            PSPhotoThumb(data: shot.photoData, label: "SHOT PHOTO", radius: 14)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    // MARK: - Edit-mode subviews

    @ViewBuilder
    private var sourcePickers: some View {
        section("Source") {
            PSCard {
                VStack(spacing: 0) {
                    PickerRow(
                        label: "Machine",
                        value: machines.first(where: { $0.persistentModelID == dMachineID })?.name ?? "—",
                        sub: machines.first(where: { $0.persistentModelID == dMachineID })?.brand,
                        options: machines.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                        selectedID: dMachineID,
                        onPick: { dMachineID = $0 }
                    )
                    PickerRow(
                        label: "Grinder",
                        value: grinders.first(where: { $0.persistentModelID == dGrinderID })?.name ?? "—",
                        sub: grinders.first(where: { $0.persistentModelID == dGrinderID })?.brand,
                        options: grinders.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                        selectedID: dGrinderID,
                        onPick: { dGrinderID = $0 }
                    )
                    PickerRow(
                        label: "Beans",
                        value: beans.first(where: { $0.persistentModelID == dBeanID })?.name ?? "—",
                        sub: beans.first(where: { $0.persistentModelID == dBeanID }).map { "\($0.roaster) · #\($0.bagNumber)" },
                        options: beans.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: "\($0.roaster) · #\($0.bagNumber)") },
                        selectedID: dBeanID,
                        onPick: { dBeanID = $0 },
                        last: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var extractionPicker: some View {
        section("Extraction") {
            HStack(spacing: 8) {
                ForEach(Extraction.allCases) { ex in
                    PSPill(
                        label: ex.rawValue,
                        active: dExtraction == ex,
                        tone: tone(ex),
                        horizontalPadding: 8,
                        verticalPadding: 11,
                        fontSize: 13,
                        action: { dExtraction = (dExtraction == ex) ? nil : ex }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var tagsPicker: some View {
        section("Tasting notes") {
            FlowLayout(spacing: 6) {
                ForEach(TastingTag.allCases) { tag in
                    PSPill(
                        label: tag.label,
                        active: dTags.contains(tag),
                        action: {
                            if dTags.contains(tag) { dTags.remove(tag) } else { dTags.insert(tag) }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var numbersEditableCard: some View {
        section("Settings") {
            PSCard {
                VStack(spacing: 0) {
                    SliderField(label: "Dose", value: $dDose, range: 7...25, step: 0.1, unit: "g", decimals: 1)
                    SliderField(label: "Yield", value: $dYield, range: 7...75, step: 0.1, unit: "g", decimals: 1)
                    SliderField(
                        label: "Water Temp",
                        value: tempBinding(celsius: $dWaterTemp),
                        range: tempUnit == .celsius ? 70...105 : 158...221,
                        step: tempUnit == .celsius ? 0.5 : 1,
                        unit: tempUnit.label,
                        decimals: tempUnit == .celsius ? 1 : 0
                    )
                    SliderField(label: "Pre-Infusion Pressure", value: $dPreInfPressure, range: 0...4, step: 0.1, unit: "bar", decimals: 1)
                    SliderField(label: "Pull Pressure", value: $dPressure, range: 4...12, step: 0.1, unit: "bar", decimals: 1)
                    SliderField(label: "Pre-infusion", value: $dPre, range: 0...20, step: 0.1, unit: "s", decimals: 1)
                    SliderField(label: "Pull", value: $dPull, range: 0...60, step: 0.1, unit: "s", decimals: 1)
                    HStack {
                        Text("Paper Filter")
                            .font(PSFont.body(13, weight: .medium))
                            .foregroundStyle(palette.inkSoft)
                        Spacer()
                        PSToggle(isOn: $dPaperFilter)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func dateEditCard(for shot: Shot) -> some View {
        section("Date / Time") {
            PSCard {
                HStack {
                    DatePicker("", selection: $dDate)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(palette.accent)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var notesEditor: some View {
        section("Notes") {
            PSCard {
                ZStack(alignment: .topLeading) {
                    if dNotes.isEmpty {
                        Text("How does it taste? What changed?")
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
                        .frame(minHeight: 78)
                }
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete shot")
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

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel(label).padding(.leading, 4)
            content()
        }
    }

    private func tone(_ ex: Extraction) -> PSPillTone {
        switch ex { case .sour: return .sour; case .perfect: return .perfect; case .bitter: return .bitter }
    }

    private func formattedPressure(_ p: Double) -> String {
        p == p.rounded() ? "\(Int(p))" : String(format: "%.1f", p)
    }

    private func formattedTemp(_ celsius: Double) -> String {
        let v = tempUnit.display(celsius: celsius)
        let s = tempUnit == .celsius
            ? (v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v))
            : "\(Int(v.rounded()))"
        return "\(s)\(tempUnit.label)"
    }

    private func tempBinding(celsius: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { tempUnit.display(celsius: celsius.wrappedValue) },
            set: { celsius.wrappedValue = tempUnit.toCelsius($0) }
        )
    }

    private func loadDraft(from shot: Shot) {
        dDate = shot.date
        dDose = shot.dose
        dYield = shot.yield
        dWaterTemp = shot.waterTemp
        dPressure = shot.pressure
        dPreInfPressure = min(max(shot.preInfPressure, 0), 4)
        dPre = shot.preInfusion
        dPull = shot.pull
        dRating = shot.rating
        dNotes = shot.notes
        dExtraction = shot.extraction
        dTags = Set(shot.tags)
        dBeanID = shot.bean?.persistentModelID
        dMachineID = shot.machine?.persistentModelID
        dGrinderID = shot.grinder?.persistentModelID
        dPhotoData = shot.photoData
        dPaperFilter = shot.usedPaperFilter
    }

    private func commitEdit(into shot: Shot) {
        shot.date = dDate
        shot.dose = dDose
        shot.yield = dYield
        shot.waterTemp = dWaterTemp
        shot.pressure = dPressure
        shot.preInfPressure = dPreInfPressure
        shot.preInfusion = dPre
        shot.pull = dPull
        shot.rating = dRating
        shot.notes = dNotes
        shot.extraction = dExtraction
        shot.tags = Array(dTags)
        shot.bean = beans.first(where: { $0.persistentModelID == dBeanID })
        shot.machine = machines.first(where: { $0.persistentModelID == dMachineID })
        shot.grinder = grinders.first(where: { $0.persistentModelID == dGrinderID })
        shot.photoData = dPhotoData
        shot.usedPaperFilter = dPaperFilter
        try? context.save()
    }
}
