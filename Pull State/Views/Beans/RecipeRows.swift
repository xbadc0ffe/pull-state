import SwiftUI

/// The three row types that make up every recipe card in the app. `RecipeBlock`
/// (Bean detail + Add Bean) and `RecipeSheet` (Log screen) both compose these,
/// so the two surfaces can never drift apart — in particular the temperature
/// row always converts through `\.psTempUnit`, so a Fahrenheit user types °F
/// everywhere while `Recipe.temp` stays Celsius on disk.
///
/// Read mode renders "—" for nil. Edit mode binds a text field to the optional
/// value; clearing the field writes nil back (never a default).

struct RecipeStringRow: View {
    let label: String
    let placeholder: String
    @Binding var value: String?
    let editing: Bool
    var last: Bool = false
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSField(label: label, last: last) {
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

struct RecipeNumberRow: View {
    let label: String
    let unit: String
    @Binding var value: Double?
    let editing: Bool
    var last: Bool = false
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSField(label: label, suffix: editing ? nil : (value == nil ? nil : unit), last: last) {
            if editing {
                HStack(spacing: 4) {
                    RecipeDecimalField(value: $value)
                    Text(unit)
                        .font(PSFont.mono(11))
                        .foregroundStyle(palette.inkMuted)
                }
            } else {
                PSValueText(text: value.map { PSFmt.number($0) } ?? "—", fontSize: 13.5)
            }
        }
    }
}

/// Temperature row. Storage is Celsius; display and input use the user's unit.
struct RecipeTempRow: View {
    let label: String
    @Binding var value: Double?
    let editing: Bool
    var last: Bool = false
    @Environment(\.psPalette) private var palette
    @Environment(\.psTempUnit) private var tempUnit

    private var displayString: String {
        guard let c = value else { return "—" }
        return PSFmt.number(tempUnit.display(celsius: c))
    }

    var body: some View {
        PSField(label: label, suffix: editing ? nil : (value == nil ? nil : tempUnit.label), last: last) {
            if editing {
                HStack(spacing: 4) {
                    RecipeDecimalField(
                        value: $value,
                        toDisplay: { tempUnit.display(celsius: $0) },
                        fromDisplay: { tempUnit.toCelsius($0) }
                    )
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

/// Shared decimal input for the numeric recipe rows. Owns the raw text while
/// the field is focused so a half-typed "18." isn't re-rendered as "18" from
/// the bound `Double`; the text is re-derived from the value on blur. Empty
/// writes nil; "," is accepted as a decimal separator; unparsable input
/// leaves the value untouched.
private struct RecipeDecimalField: View {
    @Binding var value: Double?
    var toDisplay: (Double) -> Double = { $0 }
    var fromDisplay: (Double) -> Double = { $0 }

    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.psPalette) private var palette

    var body: some View {
        TextField("—", text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .font(PSFont.mono(13.5, weight: .bold))
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(width: 80)
            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
            .onAppear { syncFromValue() }
            .onChange(of: value) { _, _ in
                if !focused { syncFromValue() }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { syncFromValue() }
            }
            .onChange(of: text) { _, raw in
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    value = nil
                } else if let n = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                    value = fromDisplay(n)
                }
            }
    }

    private func syncFromValue() {
        text = value.map { PSFmt.number(toDisplay($0)) } ?? ""
    }
}
