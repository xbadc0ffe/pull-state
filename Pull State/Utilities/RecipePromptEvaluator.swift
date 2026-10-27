// RecipePromptEvaluator.swift
//
// The post-save "Save recipe?" / "Adjust recipe?" decision, extracted from
// the Log screen as pure functions so the rules in DESIGN.md §3.1 can be unit
// tested without SwiftUI or SwiftData. `LogScreen` gathers the inputs, calls
// `evaluate`, and applies the result with `fillingNil` / `overwriting`.
import Foundation

/// Snapshot of every value the recipe-prompt logic compares against the bean's
/// saved recipe. `*Used` flags distinguish "user actually used the timer for
/// this track" from "value defaults to 0", so the apply step never overwrites
/// an existing recipe time with a zero from an unused track.
nonisolated struct RecipePromptValues: Equatable, Sendable {
    let dose: Double
    let yield: Double
    let temp: Double
    let pressure: Double
    let preInfPressure: Double
    let grind: String
    let preInfusion: Double
    let preInfusionUsed: Bool
    let pullTime: Double
    let pullTimeUsed: Bool

    var grindUsed: Bool { !grind.isEmpty }
}

/// Which post-save alert to show. Mutually exclusive with each other and with
/// "no prompt at all" — see DESIGN.md §3.1 for the rules.
nonisolated enum RecipePromptKind: Sendable {
    case save
    case adjust
}

nonisolated enum RecipePromptEvaluator {
    /// Dose and yield differ when outside ±10 % of the recipe value.
    static let percentTolerance = 0.10
    /// Water temperature differs when more than 0.6 °C away — just over one
    /// Fahrenheit slider step, so °F users don't get prompted for a nudge.
    static let tempTolerance = 0.6
    /// Pressure differs beyond 0.01 bar (slider step is 0.1).
    static let pressureTolerance = 0.01
    /// Timer green windows: ±1 s pre-infusion, ±3 s pull.
    static let preInfusionTolerance = 1.0
    static let pullTolerance = 3.0

    /// Decides which prompt (if any) follows a saved shot.
    /// - `bestRating` is the highest rating across the bean's shots *including*
    ///   the one just saved.
    static func evaluate(
        recipe r: Recipe,
        values: RecipePromptValues,
        shotRating: Int,
        bestRating: Int
    ) -> RecipePromptKind? {
        let recipeIsIncomplete = r.dose == nil || r.yield == nil || r.temp == nil || r.pullPressure == nil
        if recipeIsIncomplete { return .save }

        guard shotRating >= bestRating else { return nil }

        let valueDiffers = differsByPercent(values.dose, r.dose, percent: percentTolerance)
            || differsByPercent(values.yield, r.yield, percent: percentTolerance)
            || differs(values.temp, r.temp, tolerance: tempTolerance)
            || differs(values.pressure, r.pullPressure, tolerance: pressureTolerance)

        let preDiffers: Bool
        if let target = r.preInfTime, values.preInfusionUsed {
            preDiffers = abs(values.preInfusion - target) > preInfusionTolerance
        } else {
            preDiffers = false
        }
        let pullDiffers: Bool
        if let target = r.pullTime, values.pullTimeUsed {
            pullDiffers = abs(values.pullTime - target) > pullTolerance
        } else {
            pullDiffers = false
        }

        return (valueDiffers || preDiffers || pullDiffers) ? .adjust : nil
    }

    /// "Save recipe?" — fills only nil fields; never overwrites a set one.
    static func fillingNil(_ recipe: Recipe, with values: RecipePromptValues) -> Recipe {
        var r = recipe
        if r.dose == nil { r.dose = values.dose }
        if r.yield == nil { r.yield = values.yield }
        if r.temp == nil { r.temp = values.temp }
        if r.pullPressure == nil { r.pullPressure = values.pressure }
        if r.grind == nil, values.grindUsed { r.grind = values.grind }
        if r.preInfTime == nil, values.preInfusionUsed { r.preInfTime = values.preInfusion }
        if r.pullTime == nil, values.pullTimeUsed { r.pullTime = values.pullTime }
        return r
    }

    /// "Adjust recipe?" — overwrites the four required fields unconditionally
    /// and the optional ones only when the shot supplied a value.
    static func overwriting(_ recipe: Recipe, with values: RecipePromptValues) -> Recipe {
        var r = recipe
        r.dose = values.dose
        r.yield = values.yield
        r.temp = values.temp
        r.pullPressure = values.pressure
        if values.grindUsed { r.grind = values.grind }
        if values.preInfusionUsed { r.preInfTime = values.preInfusion }
        if values.pullTimeUsed { r.pullTime = values.pullTime }
        return r
    }

    static func differs(_ a: Double, _ b: Double?, tolerance: Double) -> Bool {
        guard let b else { return true }
        return abs(a - b) > tolerance
    }

    static func differsByPercent(_ a: Double, _ b: Double?, percent: Double) -> Bool {
        guard let b else { return true }
        return abs(a - b) > abs(b) * percent
    }
}
