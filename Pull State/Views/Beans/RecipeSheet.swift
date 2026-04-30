import SwiftUI
import SwiftData

/// "View Recipe" sheet presented from the Log screen's Source card. Read mode
/// shows the bean's eight recipe rows (nil values render as "—"); edit mode
/// binds rows to a draft `Recipe` and commits on Save. Closing while edits
/// are dirty triggers a discard-confirmation alert. Temperature rows convert
/// to/from Celsius at the UI boundary so storage stays canonical.
struct RecipeSheet: View {
    @Bindable var bean: Bean
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit

    @State private var editing = false
    @State private var draft: Recipe = Recipe()
    @State private var showDiscardAlert = false

    private var dirty: Bool { draft != bean.recipe }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if editing {
                    Button("Cancel") {
                        if dirty {
                            showDiscardAlert = true
                        } else {
                            editing = false
                        }
                    }
                    .font(PSFont.body(14))
                    .foregroundStyle(palette.inkSoft)
                    .buttonStyle(.plain)
                } else {
                    Button("Edit") {
                        draft = bean.recipe
                        editing = true
                    }
                    .font(PSFont.body(14, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .buttonStyle(.plain)
                }
                Spacer()
                if editing {
                    Button("Save") {
                        bean.recipe = draft
                        try? context.save()
                        editing = false
                    }
                    .font(PSFont.body(13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(palette.accent, in: Capsule())
                    .buttonStyle(.plain)
                    .disabled(!dirty)
                    .opacity(dirty ? 1 : 0.6)
                }
                Button {
                    if editing && dirty {
                        showDiscardAlert = true
                    } else {
                        onClose()
                    }
                } label: {
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

            VStack(spacing: 4) {
                PSDisplay(bean.name, size: 24)
                Text("BAG #\(bean.bagNumber) · RECIPE")
                    .font(PSFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(.top, 12)
            .padding(.bottom, 14)

            ScrollView {
                PSCard {
                    VStack(spacing: 0) {
                        RecipeStringField(label: "Grind", placeholder: "e.g. 22", value: editing ? $draft.grind : .constant(bean.recipe.grind), editing: editing)
                        RecipeNumField(label: "Dose", unit: "g", value: editing ? $draft.dose : .constant(bean.recipe.dose), editing: editing)
                        RecipeNumField(label: "Yield", unit: "g", value: editing ? $draft.yield : .constant(bean.recipe.yield), editing: editing)
                        RecipeTempField(label: "Water Temp", value: editing ? $draft.temp : .constant(bean.recipe.temp), editing: editing)
                        RecipeNumField(label: "Pre-Infusion Time", unit: "s", value: editing ? $draft.preInfTime : .constant(bean.recipe.preInfTime), editing: editing)
                        RecipeNumField(label: "Pre-Infusion Pressure", unit: "bar", value: editing ? $draft.preInfPressure : .constant(bean.recipe.preInfPressure), editing: editing)
                        RecipeNumField(label: "Pull Time", unit: "s", value: editing ? $draft.pullTime : .constant(bean.recipe.pullTime), editing: editing)
                        RecipeNumField(label: "Pull Pressure", unit: "bar", value: editing ? $draft.pullPressure : .constant(bean.recipe.pullPressure), editing: editing, last: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.surface)
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) {
                editing = false
                draft = bean.recipe
                onClose()
            }
        } message: {
            Text("Your edits to this recipe will be lost.")
        }
    }
}

private struct RecipeStringField: View {
    let label: String
    let placeholder: String
    @Binding var value: String?
    let editing: Bool
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSField(label: label, last: false) {
            if editing {
                TextField(placeholder, text: Binding(
                    get: { value ?? "" },
                    set: { value = $0.isEmpty ? nil : $0 }
                ))
                .font(PSFont.mono(13.5, weight: .bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(width: 120)
                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
            } else {
                PSValueText(text: (value?.isEmpty == false ? value : nil) ?? "—", fontSize: 13.5)
            }
        }
    }
}

private struct RecipeNumField: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    let editing: Bool
    var last: Bool = false
    @Environment(\.psPalette) private var palette

    private func formatted(_ d: Double) -> String {
        d == d.rounded() ? "\(Int(d))" : String(format: "%g", d)
    }

    var body: some View {
        PSField(label: label, suffix: editing ? nil : (value == nil ? nil : unit), last: last) {
            if editing {
                HStack(spacing: 4) {
                    TextField("—", text: Binding(
                        get: { value.map(formatted) ?? "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if trimmed.isEmpty {
                                value = nil
                            } else if let n = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                                value = n
                            }
                        }
                    ))
                    .modifier(PSDecimalKeyboard(active: true))
                    .font(PSFont.mono(13.5, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(width: 80)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
                    Text(unit)
                        .font(PSFont.mono(11))
                        .foregroundStyle(palette.inkMuted)
                }
            } else {
                PSValueText(text: value.map(formatted) ?? "—", fontSize: 13.5)
            }
        }
    }
}

private struct RecipeTempField: View {
    let label: String
    @Binding var value: Double?
    let editing: Bool
    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit

    private func formatted(_ d: Double) -> String {
        d == d.rounded() ? "\(Int(d))" : String(format: "%g", d)
    }

    private var displayString: String {
        guard let c = value else { return "—" }
        return formatted(tempUnit.display(celsius: c))
    }

    var body: some View {
        PSField(label: label, suffix: editing ? nil : (value == nil ? nil : tempUnit.label)) {
            if editing {
                HStack(spacing: 4) {
                    TextField("—", text: Binding(
                        get: { value.map { formatted(tempUnit.display(celsius: $0)) } ?? "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if trimmed.isEmpty {
                                value = nil
                            } else if let n = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                                value = tempUnit.toCelsius(n)
                            }
                        }
                    ))
                    .modifier(PSDecimalKeyboard(active: true))
                    .font(PSFont.mono(13.5, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(width: 80)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
                    Text(tempUnit.label)
                        .font(PSFont.mono(11))
                        .foregroundStyle(palette.inkMuted)
                }
            } else {
                PSValueText(text: displayString, fontSize: 13.5)
            }
        }
    }
}
