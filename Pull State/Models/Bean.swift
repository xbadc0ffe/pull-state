import Foundation
import SwiftData

/// One bag of coffee. Owns its shot history (cascade-deleted with the bean) and
/// carries a per-bag recipe stored as JSON `Data` (see `Recipe`). `bagNumber`
/// is monotonic via `AppSettings.nextBagNumber` and is never decremented when a
/// bean is deleted, so historical references in shot history stay stable.
@Model
final class Bean {
    var name: String
    var bagNumber: Int
    var roaster: String
    var singleOrigin: Bool
    var processRaw: String
    var processOther: String
    var roastRaw: String
    var roastDate: Date
    var purchaseDate: Date
    var notes: String
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?
    var tastingTagsRaw: [String] = []

    private var recipeData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Shot.bean)
    var shots: [Shot] = []

    init(
        name: String,
        bagNumber: Int,
        roaster: String,
        singleOrigin: Bool,
        process: BeanProcess,
        processOther: String = "",
        roast: Roast,
        roastDate: Date = .now,
        purchaseDate: Date = .now,
        notes: String = "",
        recipe: Recipe = Recipe(),
        photoData: Data? = nil,
        tastingTags: [TastingTag] = [],
        createdAt: Date = .now
    ) {
        self.name = name
        self.bagNumber = bagNumber
        self.roaster = roaster
        self.singleOrigin = singleOrigin
        self.processRaw = process.rawValue
        self.processOther = processOther
        self.roastRaw = roast.rawValue
        self.roastDate = roastDate
        self.purchaseDate = purchaseDate
        self.notes = notes
        self.photoData = photoData
        self.tastingTagsRaw = tastingTags.map(\.rawValue)
        self.createdAt = createdAt
        self.recipe = recipe
    }

    var process: BeanProcess {
        get { BeanProcess(rawValue: processRaw) ?? .other }
        set { processRaw = newValue.rawValue }
    }

    var roast: Roast {
        get { Roast(rawValue: roastRaw) ?? .medium }
        set { roastRaw = newValue.rawValue }
    }

    var processDisplay: String {
        process == .other ? (processOther.isEmpty ? "Other" : processOther) : process.rawValue
    }

    var tastingTags: [TastingTag] {
        get { tastingTagsRaw.compactMap(TastingTag.init(rawValue:)) }
        set { tastingTagsRaw = newValue.map(\.rawValue) }
    }

    var recipe: Recipe {
        get {
            guard let recipeData,
                  let decoded = try? JSONDecoder().decode(Recipe.self, from: recipeData)
            else { return Recipe() }
            return decoded
        }
        set {
            recipeData = try? JSONEncoder().encode(newValue)
        }
    }

    var ratingTrend: [BeanRatingPoint] {
        shots
            .sorted { $0.date < $1.date }
            .map { BeanRatingPoint(date: $0.date, rating: $0.rating) }
    }

    var averageRating: Double? {
        guard !shots.isEmpty else { return nil }
        return Double(shots.reduce(0) { $0 + $1.rating }) / Double(shots.count)
    }
}
