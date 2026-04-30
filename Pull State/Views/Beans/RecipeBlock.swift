import SwiftUI

/// Eight-row recipe card used inline on the Bean detail and in the Add Bean
/// form. Read-only mode shows "—" for nil fields; edit mode binds each row
/// to a draft `Recipe` so committing happens at the parent's Save action.
struct RecipeBlock: View {
    @Binding var recipe: Recipe
    let editing: Bool

    var body: some View {
        PSCard {
            VStack(spacing: 0) {
                RecipeRow(label: "Grind", text: $recipe.grind, unit: "", editing: editing, placeholder: "e.g. 22")
                RecipeNumberRow(label: "Dose", value: $recipe.dose, unit: "g", editing: editing)
                RecipeNumberRow(label: "Yield", value: $recipe.yield, unit: "g", editing: editing)
                RecipeNumberRow(label: "Water temp", value: $recipe.temp, unit: "°C", editing: editing)
                RecipeNumberRow(label: "Pre-infuse time", value: $recipe.preInfTime, unit: "s", editing: editing)
                RecipeNumberRow(label: "Pre-infuse pressure", value: $recipe.preInfPressure, unit: "bar", editing: editing)
                RecipeNumberRow(label: "Pull time", value: $recipe.pullTime, unit: "s", editing: editing)
                RecipeNumberRow(label: "Pull pressure", value: $recipe.pullPressure, unit: "bar", editing: editing, last: true)
            }
        }
    }
}

private struct RecipeRow: View {
    let label: String
    @Binding var text: String?
    let unit: String
    let editing: Bool
    var placeholder: String = ""
    var last: Bool = false
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PSFont.body(13, weight: .medium))
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                if editing {
                    TextField(placeholder, text: Binding(
                        get: { text ?? "" },
                        set: { text = $0.isEmpty ? nil : $0 }
                    ))
                    .font(PSFont.mono(13.5, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(width: 90)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text((text?.isEmpty == false ? text : nil) ?? "—")
                        .font(PSFont.mono(13.5, weight: .semibold))
                        .foregroundStyle(palette.ink)
                }
                if !unit.isEmpty {
                    Text(unit)
                        .font(PSFont.mono(11))
                        .foregroundStyle(palette.inkMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !last {
                Rectangle().fill(palette.line).frame(height: 0.5)
            }
        }
    }
}

private struct RecipeNumberRow: View {
    let label: String
    @Binding var value: Double?
    let unit: String
    let editing: Bool
    var last: Bool = false
    @Environment(\.psPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(PSFont.body(13, weight: .medium))
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                if editing {
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
                    .frame(width: 90)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(value.map(formatted) ?? "—")
                        .font(PSFont.mono(13.5, weight: .semibold))
                        .foregroundStyle(palette.ink)
                }
                Text(unit)
                    .font(PSFont.mono(11))
                    .foregroundStyle(palette.inkMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !last {
                Rectangle().fill(palette.line).frame(height: 0.5)
            }
        }
    }

    private func formatted(_ d: Double) -> String {
        d == d.rounded() ? "\(Int(d))" : String(format: "%g", d)
    }
}
