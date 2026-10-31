import SwiftUI
import SwiftData

/// History's bulk edit (Select → Edit N shots): sets the bean, machine and/or
/// grinder of every selected shot in one go. Each row starts on "Keep
/// current" (its subtitle says what the shots have now); the hardware rows
/// also offer "None"; every list ends in "+ New …", which opens the usual add
/// form and picks the result. Apply writes through `ShotReassignment.apply`,
/// which also deletes an auto-created "Unknown" bean the move leaves empty.
struct ShotBulkEditSheet: View {
    let shots: [Shot]
    let onClose: () -> Void
    let onApplied: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit

    @Query(sort: \Bean.bagNumber, order: .reverse) private var beans: [Bean]
    @Query(sort: \Equipment.createdAt) private var equipment: [Equipment]
    @Query private var settingsQuery: [AppSettings]

    /// nil keeps each shot's bean.
    @State private var beanChoice: Bean? = nil
    @State private var machineChoice: SourceChoice<Equipment> = .keep
    @State private var grinderChoice: SourceChoice<Equipment> = .keep
    @State private var showAddBean = false
    @State private var addHardwareKind: EquipmentKind? = nil

    private var machines: [Equipment] { equipment.filter { $0.kind == .machine } }
    private var grinders: [Equipment] { equipment.filter { $0.kind == .grinder } }

    private var hasChanges: Bool {
        beanChoice != nil || machineChoice != .keep || grinderChoice != .keep
    }

    private var shotsLabel: String {
        "\(shots.count) shot\(shots.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PSDisplay("Edit \(shotsLabel)", size: 20)
                Spacer()
                Button("Close", action: onClose)
                    .font(PSFont.body(14))
                    .foregroundStyle(palette.inkSoft)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .psContentColumn()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose what to change. Rows left on \u{201C}Keep current\u{201D} stay as they are on each shot.")
                        .font(PSFont.body(12))
                        .foregroundStyle(palette.inkSoft)
                        .padding(.horizontal, 4)

                    PSCard {
                        VStack(spacing: 0) {
                            beanRow
                            hardwareRow(.machine, items: machines, choice: $machineChoice)
                            hardwareRow(.grinder, items: grinders, choice: $grinderChoice, last: true)
                        }
                    }

                    Button(action: apply) {
                        Text("Apply to \(shotsLabel)")
                            .font(PSFont.body(15, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(hasChanges ? palette.accent : palette.inkMuted,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .psShadow(strong: hasChanges)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChanges)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .psContentColumn()
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showAddBean) {
            if let settings = settingsQuery.first {
                BeanAddForm(
                    settings: settings,
                    onCancel: { showAddBean = false },
                    onSaved: { bean in
                        showAddBean = false
                        beanChoice = bean
                    }
                )
                .environment(\.psPalette, palette)
                .environment(\.psTempUnit, tempUnit)
                .presentationBackground(palette.page)
            }
        }
        .sheet(item: $addHardwareKind) { kind in
            HardwareAddForm(
                kind: kind,
                offerBackfill: false,
                onCancel: { addHardwareKind = nil },
                onSaved: { item in
                    addHardwareKind = nil
                    if item.kind == .machine {
                        machineChoice = .set(item)
                    } else {
                        grinderChoice = .set(item)
                    }
                }
            )
            .environment(\.psPalette, palette)
            .environment(\.psTempUnit, tempUnit)
            .presentationBackground(palette.page)
        }
    }

    private var beanRow: some View {
        PickerRow(
            label: "Beans",
            value: beanChoice?.name ?? "Keep current",
            sub: beanChoice?.pickerSubtitle ?? currentSummary(shots.map(\.bean)) { $0.name },
            options: beans.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.pickerSubtitle) },
            selectedID: beanChoice?.persistentModelID,
            onPick: { id in beanChoice = beans.first(where: { $0.persistentModelID == id }) },
            extraChoices: [
                PickerExtraChoice(label: "Keep current", selected: beanChoice == nil, action: { beanChoice = nil })
            ],
            addLabel: "New bean",
            onAdd: { showAddBean = true }
        )
    }

    private func hardwareRow(
        _ kind: EquipmentKind,
        items: [Equipment],
        choice: Binding<SourceChoice<Equipment>>,
        last: Bool = false
    ) -> some View {
        let current = shots.map { kind == .machine ? $0.machine : $0.grinder }
        let value: String
        let sub: String?
        var selectedID: PersistentIdentifier? = nil
        switch choice.wrappedValue {
        case .keep:
            value = "Keep current"
            sub = currentSummary(current) { $0.name }
        case .clear:
            value = "None"
            sub = "Removes the \(kind.singular.lowercased()) from these shots"
        case .set(let item):
            value = item.name
            sub = item.brand
            selectedID = item.persistentModelID
        }
        return PickerRow(
            label: kind.singular,
            value: value,
            sub: sub,
            options: items.map { PickerOption(id: $0.persistentModelID, label: $0.name, sub: $0.brand) },
            selectedID: selectedID,
            onPick: { id in
                if let item = items.first(where: { $0.persistentModelID == id }) {
                    choice.wrappedValue = .set(item)
                }
            },
            last: last,
            extraChoices: [
                PickerExtraChoice(label: "Keep current", selected: choice.wrappedValue == .keep, action: { choice.wrappedValue = .keep }),
                PickerExtraChoice(label: "None", selected: choice.wrappedValue == .clear, action: { choice.wrappedValue = .clear })
            ],
            addLabel: "New \(kind.singular.lowercased())",
            onAdd: { addHardwareKind = kind }
        )
    }

    /// What the selected shots have today: "Now: Flair 58", "Now: none" or
    /// "Now: mixed".
    private func currentSummary<M: PersistentModel>(_ items: [M?], name: (M) -> String) -> String {
        let ids = Set(items.map { $0?.persistentModelID })
        if ids.count > 1 { return "Now: mixed" }
        guard let first = items.first, let model = first else { return "Now: none" }
        return "Now: \(name(model))"
    }

    private func apply() {
        ShotReassignment.apply(
            bean: beanChoice,
            machine: machineChoice,
            grinder: grinderChoice,
            to: shots,
            in: context
        )
        onApplied()
    }
}
