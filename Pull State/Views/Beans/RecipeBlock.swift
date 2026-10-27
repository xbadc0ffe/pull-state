import SwiftUI

/// Eight-row recipe card used inline on the Bean detail and in the Add Bean
/// form. Read-only mode shows "—" for nil fields; edit mode binds each row
/// to a draft `Recipe` so committing happens at the parent's Save action.
/// Rows come from `RecipeRows.swift` and are shared with `RecipeSheet`.
struct RecipeBlock: View {
    @Binding var recipe: Recipe
    let editing: Bool

    var body: some View {
        PSCard {
            VStack(spacing: 0) {
                RecipeStringRow(label: "Grind", placeholder: "e.g. 22", value: $recipe.grind, editing: editing)
                RecipeNumberRow(label: "Dose", unit: "g", value: $recipe.dose, editing: editing)
                RecipeNumberRow(label: "Yield", unit: "g", value: $recipe.yield, editing: editing)
                RecipeTempRow(label: "Water Temp", value: $recipe.temp, editing: editing)
                RecipeNumberRow(label: "Pre-Infusion Time", unit: "s", value: $recipe.preInfTime, editing: editing)
                RecipeNumberRow(label: "Pre-Infusion Pressure", unit: "bar", value: $recipe.preInfPressure, editing: editing)
                RecipeNumberRow(label: "Pull Time", unit: "s", value: $recipe.pullTime, editing: editing)
                RecipeNumberRow(label: "Pull Pressure", unit: "bar", value: $recipe.pullPressure, editing: editing, last: true)
            }
        }
    }
}
