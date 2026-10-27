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
