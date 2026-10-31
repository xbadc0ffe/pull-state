import SwiftUI
import SwiftData

/// About sheet presented from any tab's "…" icon. Houses the identity card
/// (Built by / Contact / GitHub / Temperature / Appearance switches), the
/// non-consumable tip-jar IAP, a footer tagline, and — at the very bottom —
/// "Your data": Export shots (CSV via the share sheet, `ShotCSVExport`) and
/// Wipe Data (pick a `WipeScope`, then two confirmations in a row). The
/// app-wide `StoreManager` (from the environment) owns the StoreKit state;
/// this sheet mirrors its `tipEntitled` into `AppSettings.hasTipped`, so a
/// re-installed user keeps the "tipped" state without re-purchasing.
struct AboutSheet: View {
    @Bindable var settings: AppSettings
    @Environment(\.psPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @Query private var shots: [Shot]
    @State private var restoreMessage: String?
    @State private var restoreFailed = false

    @State private var showWipeChooser = false
    @State private var showWipeConfirm = false
    @State private var showWipeFinal = false
    @State private var wipeScope: WipeScope? = nil
    @State private var wipeMessage: String?
    @State private var wipeFailed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(palette.surfaceAlt, in: Circle())
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                // Header
                VStack(spacing: 10) {
                    Image("badc0ffe-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 160)
                        .padding(.vertical, 6)
                    PSDisplay("Pull State", size: 26)
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        Text("v \(version)")
                            .font(PSFont.mono(11))
                            .tracking(1)
                            .foregroundStyle(palette.inkMuted)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)

                PSCard {
                    VStack(spacing: 0) {
                        PSField(label: "Built by") {
                            PSValueText(text: "badc0ffe", fontSize: 13)
                        }
                        PSField(label: "Contact") {
                            Text("info@badc0ffe.net")
                                .font(PSFont.mono(13, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        PSField(label: "GitHub") {
                            if let url = URL(string: "https://github.com/xbadc0ffe/pull-state") {
                                Link(destination: url) {
                                    Text("github.com/xbadc0ffe/pull-state")
                                        .font(PSFont.mono(13, weight: .semibold))
                                        .foregroundStyle(palette.accent)
                                        .underline()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                }
                            }
                        }
                        PSField(label: "Temperature") {
                            TempUnitSwitch(unit: Binding(
                                get: { settings.temperatureUnit },
                                set: { settings.temperatureUnit = $0 }
                            ))
                        }
                        PSField(label: "Appearance") {
                            ModeSwitch(appearance: Binding(
                                get: { settings.appearance },
                                set: { settings.appearance = $0 }
                            ))
                        }
                        PSField(label: "Recipe Suggestions", last: true) {
                            PSToggle(isOn: Binding(
                                get: { settings.autoRecipePromptEnabled },
                                set: { settings.autoRecipePromptEnabled = $0 }
                            ))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // Tip jar
                Button {
                    Task {
                        if await store.purchase() {
                            markTipped()
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(settings.hasTipped
                                      ? AnyShapeStyle(palette.accent)
                                      : AnyShapeStyle(LinearGradient(colors: [palette.accent, palette.accentDeep],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                                .frame(width: 42, height: 42)
                            if settings.hasTipped {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.hasTipped ? "Thanks for the coffee!" : "Buy me a coffee!")
                                .font(PSFont.body(14.5, weight: .bold))
                                .foregroundStyle(palette.ink)
                            Text(tipSubtitle)
                                .font(PSFont.body(12))
                                .foregroundStyle(palette.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if !settings.hasTipped, let price = store.displayPrice {
                            Text(price)
                                .font(PSFont.mono(13, weight: .bold))
                                .tracking(0.3)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(palette.accent, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(settings.hasTipped ? palette.accentSoft : palette.card,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(settings.hasTipped ? palette.accent : palette.lineStrong, lineWidth: 1)
                    )
                    .psShadow(strong: !settings.hasTipped)
                }
                .buttonStyle(.plain)
                .disabled(settings.hasTipped || store.purchaseInFlight || store.product == nil)
                .padding(.horizontal, 18)
                .padding(.top, 18)

                // Restore purchases
                Button {
                    Task {
                        restoreMessage = nil
                        switch await store.restore() {
                        case .restored:
                            markTipped()
                            restoreFailed = false
                            restoreMessage = "Purchase restored. Thanks for the coffee!"
                        case .nothingToRestore:
                            restoreFailed = false
                            restoreMessage = "No previous purchase found."
                        case .failed:
                            restoreFailed = true
                            restoreMessage = "Couldn't restore purchases. Try again later."
                        case .cancelled:
                            break
                        }
                    }
                } label: {
                    Text(store.restoreInFlight ? "Restoring…" : "Restore Purchases")
                        .font(PSFont.body(13, weight: .bold))
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(palette.lineStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.restoreInFlight || store.purchaseInFlight)
                .padding(.horizontal, 18)
                .padding(.top, 10)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(PSFont.body(11))
                        .foregroundStyle(restoreFailed ? palette.bad : palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 18)
                }

                Text("A precision logbook for your espresso practice.\nMade for people who care about pulls.")
                    .font(PSFont.body(12))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                if let err = store.purchaseError {
                    Text(err)
                        .font(PSFont.body(11))
                        .foregroundStyle(palette.bad)
                        .padding(.top, 10)
                        .padding(.horizontal, 18)
                }

                yourDataSection
                    .padding(.horizontal, 18)
                    .padding(.top, 26)

                Spacer(minLength: 24)
            }
            .psContentColumn()
        }
        .scrollIndicators(.hidden)
        .background(palette.surface)
        // `wipeScope` is left set when these close (it is replaced on the
        // next pick) so the dialogs' text doesn't change while they animate out.
        .alert("Are you sure?", isPresented: $showWipeFinal) {
            Button("Cancel", role: .cancel) {}
            Button(wipeScope?.confirmLabel ?? "Wipe", role: .destructive, action: performWipe)
        } message: {
            Text("This can't be undone.")
        }
        .task {
            await store.loadProductIfNeeded()
            if !settings.hasTipped, await store.hasPriorEntitlement() {
                markTipped()
            }
        }
        .onChange(of: store.tipEntitled) { _, entitled in
            if entitled { markTipped() }
        }
    }

    private var tipSubtitle: String {
        if settings.hasTipped { return "Means the world. Now back to dialing in." }
        if store.product == nil { return "The tip jar isn't available right now." }
        return "Support development with a one-time tip."
    }

    private func markTipped() {
        guard !settings.hasTipped else { return }
        settings.hasTipped = true
        try? context.save()
    }

    // MARK: - Your data

    @ViewBuilder
    private var yourDataSection: some View {
        PSSection("Your data") {
            VStack(spacing: 10) {
                exportCard
                wipeButton
                if let wipeMessage {
                    Text(wipeMessage)
                        .font(PSFont.body(11))
                        .foregroundStyle(wipeFailed ? palette.bad : palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .alert(wipeConfirmTitle, isPresented: $showWipeConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                present { showWipeFinal = true }
            }
        } message: {
            Text(wipeConfirmMessage)
        }
    }

    /// Shares the whole history as a CSV file. The file is only built when
    /// the share sheet asks for it (see `ShotCSVExport`).
    private var exportCard: some View {
        ShareLink(
            item: ShotCSVExport(
                container: context.container,
                unitRaw: settings.temperatureUnitRaw,
                fileName: ShotCSV.fileName(on: .now)
            ),
            preview: SharePreview("Pull State shot history", image: Image(systemName: "tablecells"))
        ) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.accentSoft)
                        .frame(width: 42, height: 42)
                    Image(systemName: "tablecells")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export shots")
                        .font(PSFont.body(14.5, weight: .bold))
                        .foregroundStyle(palette.ink)
                    Text(shots.isEmpty
                         ? "No shots to export yet."
                         : "\(countLabel(shots.count, "shot")) as a CSV table for Excel, Numbers or Sheets.")
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(shots.isEmpty ? palette.inkMuted : palette.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.lineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(shots.isEmpty)
    }

    private var wipeButton: some View {
        Button {
            wipeMessage = nil
            showWipeChooser = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Wipe Data")
            }
            .font(PSFont.body(13, weight: .bold))
            .foregroundStyle(palette.bad)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.bad.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .confirmationDialog("Wipe data", isPresented: $showWipeChooser, titleVisibility: .visible) {
            ForEach(WipeScope.allCases) { scope in
                Button(scope.title, role: .destructive) {
                    wipeScope = scope
                    present { showWipeConfirm = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what to delete. You'll be asked to confirm twice before anything is removed.")
        }
    }

    private var wipeConfirmTitle: String {
        switch wipeScope {
        case .shots:      return "Delete all shots?"
        case .library:    return "Delete shots, beans & hardware?"
        case .everything: return "Reset everything?"
        case nil:         return ""
        }
    }

    private var wipeConfirmMessage: String {
        let shotCount = countLabel(shots.count, "shot")
        let beanCount = countLabel((try? context.fetchCount(FetchDescriptor<Bean>())) ?? 0, "bean")
        let hardwareCount = countLabel((try? context.fetchCount(FetchDescriptor<Equipment>())) ?? 0, "hardware item")
        let body: String
        switch wipeScope {
        case .shots:
            body = "This permanently deletes \(shotCount) and their photos. Beans, recipes, hardware and settings stay."
        case .library:
            body = "This permanently deletes \(shotCount), \(beanCount) and \(hardwareCount), with their photos and recipes. Settings stay; bag numbers start again at #1."
        case .everything:
            body = "This permanently deletes every shot, bean, hardware item and photo, and resets all settings. Pull State starts over with onboarding."
        case nil:
            return ""
        }
        return body + " Export your shots first if you want a copy."
    }

    /// Runs after the second confirmation. A full reset closes the sheet
    /// first and wipes a moment later, so the switch to onboarding doesn't
    /// tear the app down under an open sheet.
    private func performWipe() {
        guard let scope = wipeScope else { return }
        if scope == .everything {
            let context = context
            let settings = settings
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                try? DataWiper.wipe(.everything, in: context, settings: settings)
            }
            return
        }
        do {
            try DataWiper.wipe(scope, in: context, settings: settings)
            wipeFailed = false
            wipeMessage = scope.doneMessage
        } catch {
            wipeFailed = true
            wipeMessage = "Couldn't wipe your data. Please try again."
        }
    }

    /// Shows the next dialog in the wipe chain once the previous one has
    /// finished animating away; presenting immediately can be dropped.
    private func present(_ show: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            show()
        }
    }

    private func countLabel(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }
}

/// Capsule segmented control for `AppearanceMode`. Used by both the About sheet
/// and the Onboarding welcome step.
struct ModeSwitch: View {
    @Binding var appearance: AppearanceMode
    @Environment(\.psPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    appearance = mode
                } label: {
                    Text(mode.label)
                        .font(PSFont.body(11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(appearance == mode ? Color.white : palette.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appearance == mode ? AnyShapeStyle(palette.accent) : AnyShapeStyle(Color.clear),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(palette.surfaceAlt, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.lineStrong, lineWidth: 0.5))
    }
}

/// Capsule segmented control for `TemperatureUnit`. Mirrors `ModeSwitch` and
/// is used by both the About sheet and the Onboarding welcome step.
struct TempUnitSwitch: View {
    @Binding var unit: TemperatureUnit
    @Environment(\.psPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TemperatureUnit.allCases) { u in
                Button {
                    unit = u
                } label: {
                    Text(u.pickerLabel)
                        .font(PSFont.body(11, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(unit == u ? Color.white : palette.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(unit == u ? AnyShapeStyle(palette.accent) : AnyShapeStyle(Color.clear),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(palette.surfaceAlt, in: Capsule())
        .overlay(Capsule().strokeBorder(palette.lineStrong, lineWidth: 0.5))
    }
}
