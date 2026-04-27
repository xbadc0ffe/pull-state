import SwiftUI
import SwiftData
import Combine
import PhotosUI

struct LogScreen: View {
    let onShowAbout: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette

    @Query(sort: \Equipment.createdAt, order: .reverse) private var allEquipment: [Equipment]
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]

    @State private var machineID: PersistentIdentifier?
    @State private var grinderID: PersistentIdentifier?
    @State private var beanID: PersistentIdentifier?
    @State private var lastLoadedBeanID: PersistentIdentifier? = nil

    @State private var dose: Double = 18.0
    @State private var yieldG: Double = 38.0
    @State private var waterTemp: Double = 93
    @State private var pressure: Double = 9
    @State private var extraction: Extraction? = nil
    @State private var tags: Set<TastingTag> = []
    @State private var rating: Int = 0
    @State private var notes: String = ""
    @State private var photoData: Data? = nil
    @State private var photoSelection: PhotosPickerItem? = nil
    @State private var shotDate: Date = .now

    @State private var tState: TimerState = .idle
    @State private var phase: TimerPhase = .pre
    @State private var elapsed: Double = 0
    @State private var preEnd: Double? = nil
    @State private var pullEnd: Double? = nil
    @State private var startInstant: Date? = nil
    @State private var savedFlash: Bool = false

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

    var body: some View {
        VStack(spacing: 0) {
            PSNavBar(title: "Log a shot", large: true) {
                EmptyView()
            } trailing: {
                PSIconBtn(systemName: "ellipsis", label: "More", action: onShowAbout)
            }

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
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if machineID == nil { machineID = machines.first?.persistentModelID }
            if grinderID == nil { grinderID = grinders.first?.persistentModelID }
            if beanID == nil { beanID = beans.first?.persistentModelID }
            preloadFromBean()
        }
        .onChange(of: beanID) { _, _ in
            preloadFromBean()
        }
        .onChange(of: photoSelection) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { photoData = data }
                }
            }
        }
        .onReceive(Timer.publish(every: 0.067, on: .main, in: .common).autoconnect()) { now in
            guard tState == .running, let startInstant else { return }
            elapsed = now.timeIntervalSince(startInstant)
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
                            options: machines.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                            selectedID: machineID,
                            onPick: { machineID = $0 }
                        )
                        PickerRow(
                            label: "Grinder",
                            value: selectedGrinder?.name ?? "—",
                            sub: selectedGrinder?.brand,
                            options: grinders.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
                            selectedID: grinderID,
                            onPick: { grinderID = $0 }
                        )
                        PickerRow(
                            label: "Beans",
                            value: selectedBean?.name ?? "—",
                            sub: selectedBean.map { "\($0.roaster) · #\($0.bagNumber)" },
                            options: beans.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: "\($0.roaster) · #\($0.bagNumber)") },
                            selectedID: beanID,
                            onPick: { beanID = $0 },
                            last: true
                        )
                    }
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
                        onManualPre: { setManualPre($0) },
                        onManualPull: { setManualPull($0) }
                    )
                    if tState != .done {
                        HStack(spacing: 8) {
                            TimerBtn(label: "START", primary: tState == .idle, disabled: tState != .idle, action: startTimer)
                            TimerBtn(label: "FIRST DRIP", primary: tState == .running && phase == .pre, disabled: !(tState == .running && phase == .pre), action: firstDrip)
                            TimerBtn(label: "DONE", primary: tState == .running && phase == .pull, disabled: tState != .running, action: doneTimer)
                        }
                    } else {
                        Button(action: resetTimer) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("RESET TIMER")
                                    .font(PSFont.mono(12, weight: .bold))
                                    .tracking(1.4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(palette.ink)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    SliderField(label: "Dose / Weight In", value: $dose, range: 10...25, step: 0.1, unit: "g", decimals: 1)
                    SliderField(label: "Yield / Weight Out", value: $yieldG, range: 15...60, step: 0.1, unit: "g", decimals: 1)
                    SliderField(label: "Water Temp", value: $waterTemp, range: 85...100, step: 1, unit: "°C", decimals: 0)
                    SliderField(label: "Pressure", value: $pressure, range: 6...12, step: 0.5, unit: "bar", decimals: 1, last: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            if selectedBean != nil {
                Text("Loaded from \(selectedBean!.name) recipe")
                    .font(PSFont.mono(10))
                    .tracking(0.6)
                    .foregroundStyle(palette.inkMuted)
                    .padding(.leading, 4)
            }
        }
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
                        tone: tone(for: ex),
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
            FlowLayout(spacing: 6) {
                ForEach(TastingTag.allCases) { tag in
                    PSPill(
                        label: tag.rawValue,
                        active: tags.contains(tag),
                        action: {
                            if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                        }
                    )
                }
            }
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
                    Group {
                        #if canImport(UIKit)
                        if let photoData, let img = UIImage(data: photoData) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            PSPlaceholder(label: "PHOTO", radius: 8)
                        }
                        #else
                        PSPlaceholder(label: "PHOTO", radius: 8)
                        #endif
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                                photoSelection = nil
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
                        PhotosPicker(selection: $photoSelection, matching: .images, photoLibrary: .shared()) {
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
                        .buttonStyle(.plain)
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

    private func tone(for ex: Extraction) -> PSPillTone {
        switch ex {
        case .sour: return .sour
        case .perfect: return .perfect
        case .bitter: return .bitter
        }
    }

    private func preloadFromBean() {
        guard let bean = selectedBean, bean.persistentModelID != lastLoadedBeanID else { return }
        let r = bean.recipe
        dose = r.dose
        yieldG = r.yield
        waterTemp = r.temp
        pressure = r.pullPressure
        lastLoadedBeanID = bean.persistentModelID
    }

    private func startTimer() {
        guard tState == .idle else { return }
        elapsed = 0
        preEnd = nil
        pullEnd = nil
        phase = .pre
        startInstant = Date()
        tState = .running
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
    }
    private func resetTimer() {
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
    }
    private func setManualPull(_ secs: Double) {
        let s = max(0, min(secs, 999))
        if preEnd == nil { preEnd = 0 }
        pullEnd = (preEnd ?? 0) + s
        tState = .done
    }

    private func save() {
        guard canSave else { return }
        let shot = Shot(
            date: shotDate,
            bean: selectedBean,
            machine: selectedMachine,
            grinder: selectedGrinder,
            grindSetting: selectedBean?.recipe.grind ?? "",
            dose: dose,
            yield: yieldG,
            waterTemp: waterTemp,
            pressure: pressure,
            preInfusion: preEnd ?? 0,
            pull: (pullEnd ?? 0) - (preEnd ?? 0),
            extraction: extraction,
            tags: Array(tags),
            rating: rating,
            notes: notes,
            photoData: photoData
        )
        context.insert(shot)
        try? context.save()

        resetTimer()
        rating = 0
        extraction = nil
        tags = []
        notes = ""
        photoData = nil
        photoSelection = nil
        shotDate = .now

        savedFlash = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run { savedFlash = false }
        }
    }
}

enum TimerState { case idle, running, done }
enum TimerPhase { case pre, pull }
