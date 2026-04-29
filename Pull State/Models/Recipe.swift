import Foundation

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

nonisolated struct BeanRatingPoint: Codable, Identifiable, Equatable, Sendable {
    var date: Date
    var rating: Int

    var id: Date { date }
}
