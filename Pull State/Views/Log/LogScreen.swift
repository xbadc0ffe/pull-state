import SwiftUI
import SwiftData
import UIKit

/// The Log tab — primary surface for timing and saving a shot. Owns the timer
/// state machine (idle/running/done × pre/pull), the source pickers
/// (pre-selected from the most recently logged shot), the slider settings
/// (preloaded from the selected bean's recipe, only filling fields whose
/// recipe value is non-nil), and the post-save recipe prompt — the rules live
/// in `RecipePromptEvaluator`; see DESIGN.md §3.1. The screen stays mounted
/// while other tabs are shown (see `MainTabView`), so a running timer and a
/// half-written shot survive tab switches.
struct LogScreen: View {
    let onShowAbout: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit

    @Query(sort: \Equipment.createdAt, order: .reverse) private var allEquipment: [Equipment]
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @Query private var settingsQuery: [AppSettings]
    private var settings: AppSettings? { settingsQuery.first }

    @State private var machineID: PersistentIdentifier?
    @State private var grinderID: PersistentIdentifier?
    @State private var beanID: PersistentIdentifier?
    @State private var lastLoadedBeanID: PersistentIdentifier? = nil

    @State private var dose: Double = 18.0
    @State private var yieldG: Double = 38.0
    @State private var waterTemp: Double = 93
    @State private var pressure: Double = 9
    @State private var preInfPressure: Double = 1.0
    @State private var grind: String = ""
    @State private var usedPaperFilter: Bool = false
    @State private var extraction: Extraction? = nil
    @State private var tags: Set<TastingTag> = []
    @State private var rating: Int = 0
    @State private var notes: String = ""
    @State private var photoData: Data? = nil
    @State private var shotDate: Date = .now

    @State private var tState: TimerState = .idle
    @State private var phase: TimerPhase = .pre
    @State private var elapsed: Double = 0
    @State private var preEnd: Double? = nil
    @State private var pullEnd: Double? = nil
    @State private var startInstant: Date? = nil
    /// ~15 Hz readout refresh while the timer runs; nil when idle or done so
    /// the Log tab does no periodic work between shots.
    @State private var tickTask: Task<Void, Never>? = nil
    @State private var savedFlash: Bool = false
    @State private var showRecipeSheet: Bool = false
    @State private var recipePrompt: RecipePrompt? = nil

    private var machines: [Equipment] { allEquipment.filter { $0.kind == .machine } }
    private var grinders: [Equipment] { allEquipment.filter { $0.kind == .grinder } }

    private var selectedMachine: Equipment? { machines.first(where: { $0.persistentModelID == machineID }) ?? machines.first }
    private var selectedGrinder: Equipment? { grinders.first(where: { $0.persistentModelID == grinderID }) ?? grinders.first }
    private var selectedBean: Bean? { beans.first(where: { $0.persistentModelID == beanID }) ?? beans.first }

    private var preInfusion: Double {
        if let preEnd { return preEnd }
        if tState == .running, phase == .pre { return elapsed }
        return 0
    }
    private var pullTime: Double {
        if let pullEnd { return pullEnd - (preEnd ?? 0) }
        if tState == .running, phase == .pull { return elapsed - (preEnd ?? 0) }
        return 0
    }
    private var ratio: Double { dose > 0 ? yieldG / dose : 0 }

    private var preInGreenWindow: Bool {
        guard let target = selectedBean?.recipe.preInfTime, target > 0 else { return false }
        return preInfusion >= target - 1 && preInfusion <= target + 1
    }
    private var pullInGreenWindow: Bool {
        guard let target = selectedBean?.recipe.pullTime, target > 0 else { return false }
        return pullTime >= target - 3 && pullTime <= target + 3
    }

    var body: some View {
        VStack(spacing: 0) {
            PSNavBar(title: "Log a shot", large: true) {
                EmptyView()
            } trailing: {
                PSIconBtn(systemName: "ellipsis", label: "More", action: onShowAbout)
            }
            .psContentColumn()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sourceSection
                    timerSection
                    settingsSection
                    extractionSection
                    tastingSection
                    ratingSection
                    photoAndDateCard
                    notesSection
                    saveButton
                    Text("· · · · · · ·")
                        .font(PSFont.mono(9.5))
                        .tracking(1)
                        .foregroundStyle(palette.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .psContentColumn()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded { dismissKeyboard() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            var lastShotDescriptor = FetchDescriptor<Shot>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            lastShotDescriptor.fetchLimit = 1
            let lastShot = (try? context.fetch(lastShotDescriptor))?.first
            if machineID == nil {
                machineID = lastShot?.machine?.persistentModelID ?? machines.first?.persistentModelID
            }
            if grinderID == nil {
                grinderID = lastShot?.grinder?.persistentModelID ?? grinders.first?.persistentModelID
            }
            if beanID == nil {
                beanID = lastShot?.bean?.persistentModelID ?? beans.first?.persistentModelID
            }
            preloadFromBean()
        }
        .onChange(of: beanID) { _, _ in
            preloadFromBean()
        }
        .sheet(isPresented: $showRecipeSheet) {
            if let bean = selectedBean {
                RecipeSheet(bean: bean, onClose: { showRecipeSheet = false })
                    .environment(\.psPalette, palette)
                    .environment(\.psTempUnit, tempUnit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(palette.surface)
            }
        }
        .alert(
            recipePromptTitle,
            isPresented: Binding(
                get: { recipePrompt != nil },
                set: { if !$0 { recipePrompt = nil } }
            )
        ) {
            Button(recipePromptConfirmLabel) {
                applyRecipePrompt()
            }
            Button("Don't ask again") {
                settings?.autoRecipePromptEnabled = false
                try? context.save()
                recipePrompt = nil
            }
            Button("Skip", role: .cancel) {
                recipePrompt = nil
            }
        } message: {
            Text(recipePromptMessage)
        }
    }

    private var recipePromptTitle: String {
        switch recipePrompt?.kind {
        case .save: return "Save recipe?"
        case .adjust: return "Adjust recipe?"
        case .none: return ""
        }
    }
    private var recipePromptMessage: String {
        let beanName = recipePrompt?.bean.name ?? "this bean"
        switch recipePrompt?.kind {
        case .save: return "Save these settings as the recipe for \(beanName)?"
        case .adjust: return "This pull matches or beats your best for \(beanName). Update the recipe with these settings?"
        case .none: return ""
        }
    }
    private var recipePromptConfirmLabel: String {
        switch recipePrompt?.kind {
        case .save: return "Save Recipe"
        case .adjust: return "Update Recipe"
        case .none: return "Save"
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Source").padding(.leading, 4)
            if machines.isEmpty || grinders.isEmpty || beans.isEmpty {
                PSCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Set up your gear first")
                            .font(PSFont.body(13, weight: .semibold))
                            .foregroundStyle(palette.ink)
                        Text("Add at least one bean (Beans tab), one machine, and one grinder (Hardware tab) before logging a shot.")
                            .font(PSFont.body(12))
                            .foregroundStyle(palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
            } else {
                PSCard {
                    VStack(spacing: 0) {
                        PickerRow(
                            label: "Machine",
                            value: selectedMachine?.name ?? "—",
                            sub: selectedMachine?.brand,
                            options: machines.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand, photoData: $0.photoData) },
                            selectedID: machineID,
                            onPick: { machineID = $0 },
                            photoData: selectedMachine?.photoData,
                            showThumbnails: true
                        )
                        PickerRow(
                            label: "Grinder",
                            value: selectedGrinder?.name ?? "—",
                            sub: selectedGrinder?.brand,
                            options: grinders.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand, photoData: $0.photoData) },
                            selectedID: grinderID,
                            onPick: { grinderID = $0 },
                            photoData: selectedGrinder?.photoData,
                            showThumbnails: true
                        )
                        PickerRow(
                            label: "Beans",
                            value: selectedBean?.name ?? "—",
                            sub: selectedBean.map { "\($0.roaster) · #\($0.bagNumber)" },
                            options: beans.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: "\($0.roaster) · #\($0.bagNumber)", photoData: $0.photoData) },
                            selectedID: beanID,
                            onPick: { beanID = $0 },
                            last: true,
                            photoData: selectedBean?.photoData,
                            showThumbnails: true
                        )
                    }
                }
                if selectedBean != nil {
                    Button { showRecipeSheet = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("View Recipe")
                                .font(PSFont.body(12, weight: .semibold))
                        }
                        .foregroundStyle(palette.accentDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(palette.accentSoft, in: Capsule())
                        .overlay(Capsule().strokeBorder(palette.accent, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Timer").padding(.leading, 4)
            PSCard {
                VStack(spacing: 14) {
                    DualTrackTimer(
                        preInfusion: preInfusion,
                        pullTime: pullTime,
                        running: tState == .running,
                        phase: phase,
                        done: tState == .done,
                        editable: tState != .running,
                        preInfTarget: selectedBean?.recipe.preInfTime,
                        pullTarget: selectedBean?.recipe.pullTime,
                        onManualPre: { setManualPre($0) },
                        onManualPull: { setManualPull($0) }
                    )
                    if tState != .done {
                        HStack(spacing: 10) {
                            TimerBtn(label: "START", primary: tState == .idle, disabled: tState != .idle, action: startTimer)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(minWidth: 64, minHeight: 64)
                            TimerBtn(label: "FIRST DRIP", primary: tState == .running && phase == .pre, disabled: !(tState == .running && phase == .pre), inGreenWindow: preInGreenWindow, action: firstDrip)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(minWidth: 64, minHeight: 64)
                            TimerBtn(label: "DONE", primary: tState == .running && phase == .pull, disabled: tState != .running, inGreenWindow: pullInGreenWindow, action: doneTimer)
                                .aspectRatio(1, contentMode: .fit)
                                .frame(minWidth: 64, minHeight: 64)
                        }
                    } else {
                        Button(action: resetTimer) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("RESET TIMER")
                                    .font(PSFont.mono(13, weight: .bold))
                                    .tracking(1.4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundStyle(palette.ink)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(palette.lineStrong, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Settings").padding(.leading, 4)
            PSCard {
                VStack(spacing: 0) {
                    grindField
                    SliderField(label: "Dose / Weight In", value: $dose, range: 7...25, step: 0.1, unit: "g", decimals: 1)
                    SliderField(label: "Yield / Weight Out", value: $yieldG, range: 7...75, step: 0.1, unit: "g", decimals: 1)
                    SliderField(
                        label: "Water Temp",
                        value: tempBinding(celsius: $waterTemp),
                        range: tempRange,
                        step: tempStep,
                        unit: tempUnit.label,
                        decimals: tempUnit == .celsius ? 1 : 0
                    )
                    SliderField(label: "Pre-Infusion Pressure", value: $preInfPressure, range: 0...4, step: 0.1, unit: "bar", decimals: 1)
                    SliderField(label: "Pull Pressure", value: $pressure, range: 4...12, step: 0.1, unit: "bar", decimals: 1)
                    paperFilterRow
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            if let bean = selectedBean {
                Text("Loaded from \(bean.name) recipe")
                    .font(PSFont.mono(10))
                    .tracking(0.6)
                    .foregroundStyle(palette.inkMuted)
                    .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private var grindField: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Grind Setting")
                .font(PSFont.body(13, weight: .medium))
                .foregroundStyle(palette.inkSoft)
            Spacer(minLength: 12)
            TextField("e.g. 22", text: $grind)
                .font(PSFont.mono(15, weight: .semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(palette.line)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var paperFilterRow: some View {
        HStack {
            Text("Paper Filter")
                .font(PSFont.body(13, weight: .medium))
                .foregroundStyle(palette.inkSoft)
            Spacer()
            PSToggle(isOn: $usedPaperFilter, label: "Paper Filter")
        }
        .padding(.vertical, 12)
    }

    private var tempRange: ClosedRange<Double> {
        tempUnit == .celsius ? 70...105 : 158...221
    }
    private var tempStep: Double {
        tempUnit == .celsius ? 0.5 : 1
    }
    private func tempBinding(celsius: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { tempUnit.display(celsius: celsius.wrappedValue) },
            set: { celsius.wrappedValue = tempUnit.toCelsius($0) }
        )
    }

    @ViewBuilder
    private var extractionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Extraction").padding(.leading, 4)
            HStack(spacing: 8) {
                ForEach(Extraction.allCases) { ex in
                    PSPill(
                        label: ex.rawValue,
                        active: extraction == ex,
                        tone: PSPillTone(ex),
                        horizontalPadding: 8,
                        verticalPadding: 11,
                        fontSize: 13,
                        action: { extraction = (extraction == ex) ? nil : ex }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var tastingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Tasting notes").padding(.leading, 4)
            FlowLayout(spacing: 6, alignment: .center) {
                ForEach(TastingTag.allCases) { tag in
                    PSPill(
                        label: tag.label,
                        active: tags.contains(tag),
                        action: {
                            if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Rating").padding(.leading, 4)
            PSCard {
                HStack {
                    Text("How was it?")
                        .font(PSFont.body(13))
                        .foregroundStyle(palette.inkSoft)
                    Spacer()
                    PSStars(value: $rating)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var photoAndDateCard: some View {
        PSCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    PSPhotoThumb(data: photoData, label: "PHOTO", radius: 8)
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Photo")
                            .font(PSFont.body(13, weight: .medium))
                            .foregroundStyle(palette.inkSoft)
                        Text(photoData == nil ? "Optional" : "Attached")
                            .font(PSFont.body(11))
                            .foregroundStyle(palette.inkMuted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        if photoData != nil {
                            Button {
                                photoData = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(palette.inkSoft)
                                    .frame(width: 28, height: 28)
                                    .background(palette.surface, in: Circle())
                                    .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove photo")
                        }
                        PSPhotoSourceMenu(data: $photoData) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.system(size: 12, weight: .regular))
                                Text(photoData == nil ? "Add" : "Change")
                                    .font(PSFont.body(12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(photoData == nil ? palette.ink : Color.white)
                            .background(photoData == nil ? palette.surface : palette.accent, in: Capsule())
                            .overlay(Capsule().strokeBorder(palette.line, lineWidth: 0.5))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Rectangle().fill(palette.line).frame(height: 0.5)

                HStack {
                    Text("Date / Time")
                        .font(PSFont.body(13, weight: .medium))
                        .foregroundStyle(palette.inkSoft)
                    Spacer()
                    DatePicker("", selection: $shotDate)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accentColor(palette.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PSSectionLabel("Notes").padding(.leading, 4)
            PSCard {
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("How does it taste? What changed?")
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
                        .frame(minHeight: 78)
                }
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        Button(action: save) {
            Text(savedFlash ? "SAVED ✓" : "SAVE SHOT")
                .font(PSFont.body(15, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(canSave ? palette.accent : palette.inkMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .psShadow(strong: canSave)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        selectedBean != nil && selectedMachine != nil && selectedGrinder != nil
    }

    // MARK: - Actions

    private func evaluateRecipePrompt(bean: Bean, values: RecipePromptValues, shotRating: Int) {
        guard settings?.autoRecipePromptEnabled ?? true else { return }
        let bestRating = bean.shots.map(\.rating).max() ?? 0
        if let kind = RecipePromptEvaluator.evaluate(
            recipe: bean.recipe, values: values, shotRating: shotRating, bestRating: bestRating
        ) {
            recipePrompt = RecipePrompt(kind: kind, bean: bean, values: values)
        }
    }

    private func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func applyRecipePrompt() {
        guard let prompt = recipePrompt else { return }
        switch prompt.kind {
        case .save:
            prompt.bean.recipe = RecipePromptEvaluator.fillingNil(prompt.bean.recipe, with: prompt.values)
        case .adjust:
            prompt.bean.recipe = RecipePromptEvaluator.overwriting(prompt.bean.recipe, with: prompt.values)
        }
        try? context.save()
        recipePrompt = nil
    }

    private func preloadFromBean() {
        guard let bean = selectedBean, bean.persistentModelID != lastLoadedBeanID else { return }
        let r = bean.recipe
        if let d = r.dose { dose = d }
        if let y = r.yield { yieldG = y }
        if let t = r.temp { waterTemp = t }
        if let p = r.pullPressure { pressure = p }
        if let pp = r.preInfPressure { preInfPressure = min(max(pp, 0), 4) }
        if let g = r.grind { grind = g } else { grind = "" }
        lastLoadedBeanID = bean.persistentModelID
    }

    private func startTimer() {
        guard tState == .idle else { return }
        elapsed = 0
        preEnd = nil
        pullEnd = nil
        phase = .pre
        let start = Date()
        startInstant = start
        tState = .running
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(start)
                try? await Task.sleep(for: .milliseconds(67))
            }
        }
    }
    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
    private func firstDrip() {
        guard tState == .running, phase == .pre else { return }
        preEnd = elapsed
        phase = .pull
    }
    private func doneTimer() {
        guard tState == .running else { return }
        if preEnd == nil { preEnd = elapsed }
        pullEnd = elapsed
        tState = .done
        stopTicking()
    }
    private func resetTimer() {
        stopTicking()
        tState = .idle
        phase = .pre
        elapsed = 0
        preEnd = nil
        pullEnd = nil
        startInstant = nil
    }
    private func setManualPre(_ secs: Double) {
        let s = max(0, min(secs, 999))
        let currentPull = pullTime
        preEnd = s
        pullEnd = s + currentPull
        tState = .done
        stopTicking()
    }
    private func setManualPull(_ secs: Double) {
        let s = max(0, min(secs, 999))
        if preEnd == nil { preEnd = 0 }
        pullEnd = (preEnd ?? 0) + s
        tState = .done
        stopTicking()
    }

    private func save() {
        guard canSave else { return }
        let bean = selectedBean
        let preInfusionUsed = preEnd != nil
        let pullTimeUsed = pullEnd != nil
        let preInfusionSeconds = roundedTenth(preEnd ?? 0)
        let pullSeconds = roundedTenth((pullEnd ?? 0) - (preEnd ?? 0))
        let shotRating = rating
        let trimmedGrind = grind.trimmingCharacters(in: .whitespacesAndNewlines)

        let values = RecipePromptValues(
            dose: dose,
            yield: yieldG,
            temp: waterTemp,
            pressure: pressure,
            preInfPressure: preInfPressure,
            grind: trimmedGrind,
            preInfusion: preInfusionSeconds,
            preInfusionUsed: preInfusionUsed,
            pullTime: pullSeconds,
            pullTimeUsed: pullTimeUsed
        )

        let shot = Shot(
            date: shotDate,
            bean: bean,
            machine: selectedMachine,
            grinder: selectedGrinder,
            grindSetting: trimmedGrind,
            dose: values.dose,
            yield: values.yield,
            waterTemp: values.temp,
            pressure: values.pressure,
            preInfPressure: values.preInfPressure,
            preInfusion: preInfusionSeconds,
            pull: pullSeconds,
            extraction: extraction,
            tags: Array(tags),
            rating: shotRating,
            notes: notes,
            usedPaperFilter: usedPaperFilter,
            photoData: photoData
        )
        context.insert(shot)
        try? context.save()

        if let bean {
            evaluateRecipePrompt(bean: bean, values: values, shotRating: shotRating)
        }

        resetTimer()
        rating = 0
        extraction = nil
        tags = []
        notes = ""
        photoData = nil
        shotDate = .now
        grind = selectedBean?.recipe.grind ?? ""

        savedFlash = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run { savedFlash = false }
        }
    }
}

/// Three-state timer machine: `.idle` → `.running` → `.done` → reset → `.idle`.
enum TimerState { case idle, running, done }

/// Active sub-track within the running timer.
enum TimerPhase { case pre, pull }

/// Post-save prompt payload: which kind of prompt to show, the bean to update,
/// and the recipe values pulled from the just-saved shot.
struct RecipePrompt {
    let kind: RecipePromptKind
    let bean: Bean
    let values: RecipePromptValues
}

@MainActor
private func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}
