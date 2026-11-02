import SwiftUI
import SwiftData

/// "View Recipe" sheet presented from the Log screen's Source card. Read mode
/// shows the bean's eight recipe rows (nil values render as "—"); edit mode
/// binds rows to a draft `Recipe` and commits on Save. Closing while edits
/// are dirty triggers a discard-confirmation alert. Temperature rows convert
/// to/from Celsius at the UI boundary so storage stays canonical. Rows are
/// the shared `RecipeRows.swift` views, also used by `RecipeBlock`.
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
            HStack(spacing: 10) {
                if editing {
                    PSNavTextButton(title: "Cancel", muted: true) {
                        if dirty {
                            showDiscardAlert = true
                        } else {
                            editing = false
                        }
                    }
                } else {
                    PSNavTextButton(title: "Edit", weight: .semibold) {
                        draft = bean.recipe
                        editing = true
                    }
                }
                Spacer()
                if editing {
                    PSNavSaveButton(enabled: dirty) {
                        bean.recipe = draft
                        try? context.save()
                        editing = false
                    }
                }
                PSNavCloseButton {
                    if editing && dirty {
                        showDiscardAlert = true
                    } else {
                        onClose()
                    }
                }
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
                        RecipeStringRow(label: "Grind", placeholder: "e.g. 22", value: editing ? $draft.grind : .constant(bean.recipe.grind), editing: editing)
                        RecipeNumberRow(label: "Dose", unit: "g", value: editing ? $draft.dose : .constant(bean.recipe.dose), editing: editing)
                        RecipeNumberRow(label: "Yield", unit: "g", value: editing ? $draft.yield : .constant(bean.recipe.yield), editing: editing)
                        RecipeTempRow(label: "Water Temp", value: editing ? $draft.temp : .constant(bean.recipe.temp), editing: editing)
                        RecipeNumberRow(label: "Pre-Infusion Time", unit: "s", value: editing ? $draft.preInfTime : .constant(bean.recipe.preInfTime), editing: editing)
                        RecipeNumberRow(label: "Pre-Infusion Pressure", unit: "bar", value: editing ? $draft.preInfPressure : .constant(bean.recipe.preInfPressure), editing: editing)
                        RecipeNumberRow(label: "Pull Time", unit: "s", value: editing ? $draft.pullTime : .constant(bean.recipe.pullTime), editing: editing)
                        RecipeNumberRow(label: "Pull Pressure", unit: "bar", value: editing ? $draft.pullPressure : .constant(bean.recipe.pullPressure), editing: editing, last: true)
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
