import Foundation

/// A bean's dialed-in target settings. Stored as JSON `Data` on `Bean.recipeData`
/// rather than as a `@Model`. Every field is optional and there are no defaults
/// — a fresh `Recipe()` is genuinely "nothing specified yet". Read sites must
/// guard for nil; write sites that pre-fill recipes (the post-save "Save
/// recipe?" / "Adjust recipe?" prompts on the Log screen) only touch fields
/// the user has supplied a value for, and never overwrite an existing recipe
/// field with nil. See DESIGN.md §3.1 and §4.5 for the full prompt logic.
nonisolated struct Recipe: Codable, Equatable, Sendable {
    var grind: String?
    var dose: Double?
    var yield: Double?
    var temp: Double?
    var preInfTime: Double?
    var preInfPressure: Double?
    var pullTime: Double?
    var pullPressure: Double?

    init(
        grind: String? = nil,
        dose: Double? = nil,
        yield: Double? = nil,
        temp: Double? = nil,
        preInfTime: Double? = nil,
        preInfPressure: Double? = nil,
        pullTime: Double? = nil,
        pullPressure: Double? = nil
    ) {
        self.grind = grind
        self.dose = dose
        self.yield = yield
        self.temp = temp
        self.preInfTime = preInfTime
        self.preInfPressure = preInfPressure
        self.pullTime = pullTime
        self.pullPressure = pullPressure
    }

    enum CodingKeys: String, CodingKey {
        case grind, dose, yield, temp, preInfTime, preInfPressure, pullTime, pullPressure
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.grind = try c.decodeIfPresent(String.self, forKey: .grind)
        self.dose = try c.decodeIfPresent(Double.self, forKey: .dose)
        self.yield = try c.decodeIfPresent(Double.self, forKey: .yield)
        self.temp = try c.decodeIfPresent(Double.self, forKey: .temp)
        self.preInfTime = try c.decodeIfPresent(Double.self, forKey: .preInfTime)
        self.preInfPressure = try c.decodeIfPresent(Double.self, forKey: .preInfPressure)
        self.pullTime = try c.decodeIfPresent(Double.self, forKey: .pullTime)
        self.pullPressure = try c.decodeIfPresent(Double.self, forKey: .pullPressure)
    }
}

/// One data point on the per-bean rating trend chart — a (date, rating) pair
/// derived from the bean's shot history. Computed on demand by `Bean.ratingTrend`.
nonisolated struct BeanRatingPoint: Codable, Identifiable, Equatable, Sendable {
    var date: Date
    var rating: Int

    var id: Date { date }
}
