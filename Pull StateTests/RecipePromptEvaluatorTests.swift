import Testing
@testable import Pull_State

/// Covers the post-save prompt rules from DESIGN.md §3.1.
struct RecipePromptEvaluatorTests {
    private func values(
        dose: Double = 18, yield: Double = 36, temp: Double = 93, pressure: Double = 9,
        grind: String = "22", pre: Double = 8, preUsed: Bool = true,
        pull: Double = 28, pullUsed: Bool = true
    ) -> RecipePromptValues {
        RecipePromptValues(
            dose: dose, yield: yield, temp: temp, pressure: pressure, preInfPressure: 1,
            grind: grind, preInfusion: pre, preInfusionUsed: preUsed,
            pullTime: pull, pullTimeUsed: pullUsed
        )
    }

    private let complete = Recipe(grind: "22", dose: 18, yield: 36, temp: 93, preInfTime: 8, pullTime: 28, pullPressure: 9)

    @Test func incompleteRecipePromptsSave() {
        let partial = Recipe(dose: 18, yield: 36) // temp + pullPressure missing
        #expect(RecipePromptEvaluator.evaluate(recipe: partial, values: values(), shotRating: 1, bestRating: 5) == .save)
        #expect(RecipePromptEvaluator.evaluate(recipe: Recipe(), values: values(), shotRating: 0, bestRating: 0) == .save)
    }

    @Test func matchingShotPromptsNothing() {
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(), shotRating: 5, bestRating: 5) == nil)
    }

    @Test func lowerRatedShotNeverPromptsAdjust() {
        let v = values(dose: 20) // >10% off
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: v, shotRating: 3, bestRating: 4) == nil)
    }

    @Test func doseWithinTenPercentIsNotADifference() {
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(dose: 19.5), shotRating: 5, bestRating: 5) == nil)
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(dose: 20.0), shotRating: 5, bestRating: 5) == .adjust)
    }

    @Test func temperatureNudgeWithinOneFahrenheitStepIsIgnored() {
        // 1 °F ≈ 0.556 °C: a Fahrenheit user sliding one notch must not be prompted.
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(temp: 93.556), shotRating: 5, bestRating: 5) == nil)
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(temp: 94), shotRating: 5, bestRating: 5) == .adjust)
    }

    @Test func pressureDifferencePromptsAdjust() {
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(pressure: 8.9), shotRating: 5, bestRating: 5) == .adjust)
    }

    @Test func timerWindowsOnlyCountWhenTimerWasUsed() {
        // Outside the ±3 s pull window, but the timer wasn't used → ignored.
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(pull: 40, pullUsed: false), shotRating: 5, bestRating: 5) == nil)
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(pull: 40, pullUsed: true), shotRating: 5, bestRating: 5) == .adjust)
        // Inside the window.
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(pull: 30.5), shotRating: 5, bestRating: 5) == nil)
        // Pre-infusion ±1 s.
        #expect(RecipePromptEvaluator.evaluate(recipe: complete, values: values(pre: 9.5), shotRating: 5, bestRating: 5) == .adjust)
    }

    @Test func fillingNilNeverOverwrites() {
        let partial = Recipe(grind: "20", dose: 17)
        let filled = RecipePromptEvaluator.fillingNil(partial, with: values(grind: "22", pre: 0, preUsed: false))
        #expect(filled.grind == "20")
        #expect(filled.dose == 17)
        #expect(filled.yield == 36)
        #expect(filled.temp == 93)
        #expect(filled.pullPressure == 9)
        #expect(filled.preInfTime == nil)   // timer track unused → stays nil
        #expect(filled.pullTime == 28)
    }

    @Test func overwritingReplacesRequiredFieldsAndKeepsUnusedOptionalOnes() {
        let updated = RecipePromptEvaluator.overwriting(complete, with: values(dose: 19, grind: "", pre: 0, preUsed: false, pull: 0, pullUsed: false))
        #expect(updated.dose == 19)
        #expect(updated.grind == "22")      // empty grind → keep
        #expect(updated.preInfTime == 8)    // unused track → keep
        #expect(updated.pullTime == 28)
    }
}
