import Foundation

nonisolated struct Recipe: Codable, Equatable, Sendable {
    var grind: String
    var dose: Double
    var yield: Double
    var temp: Double
    var preInfTime: Double
    var preInfPressure: Double
    var pullTime: Double
    var pullPressure: Double

    static let `default` = Recipe(
        grind: "",
        dose: 18,
        yield: 38,
        temp: 93,
        preInfTime: 7,
        preInfPressure: 3,
        pullTime: 28,
        pullPressure: 9
    )

    init(
        grind: String = "",
        dose: Double = 18,
        yield: Double = 38,
        temp: Double = 93,
        preInfTime: Double = 7,
        preInfPressure: Double = 3,
        pullTime: Double = 28,
        pullPressure: Double = 9
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
        self.grind = try c.decodeIfPresent(String.self, forKey: .grind) ?? ""
        self.dose = try c.decodeIfPresent(Double.self, forKey: .dose) ?? 18
        self.yield = try c.decodeIfPresent(Double.self, forKey: .yield) ?? 38
        self.temp = try c.decodeIfPresent(Double.self, forKey: .temp) ?? 93
        self.preInfTime = try c.decodeIfPresent(Double.self, forKey: .preInfTime) ?? 7
        self.preInfPressure = try c.decodeIfPresent(Double.self, forKey: .preInfPressure) ?? 3
        self.pullTime = try c.decodeIfPresent(Double.self, forKey: .pullTime) ?? 28
        self.pullPressure = try c.decodeIfPresent(Double.self, forKey: .pullPressure) ?? 9
    }
}

nonisolated struct BeanRatingPoint: Codable, Identifiable, Equatable, Sendable {
    var date: Date
    var rating: Int

    var id: Date { date }
}
