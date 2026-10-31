import Foundation
import SwiftData

/// One bag of coffee. Owns its shot history (cascade-deleted with the bean) and
/// carries a per-bag recipe stored as JSON `Data` (see `Recipe`). `bagNumber`
/// is monotonic via `AppSettings.nextBagNumber` and is never decremented when a
/// bean is deleted, so historical references in shot history stay stable.
///
/// A bean created from the Log screen's save prompt (`quickAdd`) only knows
/// its name: `roastRaw` / `processRaw` are empty, which `roastIfSet` /
/// `processIfSet` report as nil so the UI shows nothing rather than a made-up
/// "Medium · Washed".
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
    /// True only for the "Unknown" bean the Log screen creates when a shot is
    /// saved before any bean exists and the name prompt is left blank. Such a
    /// placeholder is deleted once its last shot moves to another bean
    /// (`ShotReassignment.removeEmptyPlaceholders`). Saving an edit on the
    /// bean's page clears the flag, so a bean the user has adopted stays.
    var isPlaceholder: Bool = false

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

    /// The roast level, or nil when it was never set (a quick-added bean).
    var roastIfSet: Roast? { Roast(rawValue: roastRaw) }

    /// The process, or nil when it was never set (a quick-added bean).
    var processIfSet: BeanProcess? { BeanProcess(rawValue: processRaw) }

    var processDisplay: String {
        process == .other ? (processOther.isEmpty ? "Other" : processOther) : process.rawValue
    }

    /// "Roaster · #3" for picker rows, or just "#3" when no roaster is set.
    var pickerSubtitle: String {
        roaster.isEmpty ? "#\(bagNumber)" : "\(roaster) · #\(bagNumber)"
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

    /// Shots the user actually rated (1–5). Unrated shots (rating 0) are
    /// excluded from the trend chart and the average so they don't read as
    /// "zero stars".
    var ratedShots: [Shot] { shots.filter { $0.rating > 0 } }

    var ratingTrend: [BeanRatingPoint] {
        ratedShots
            .sorted { $0.date < $1.date }
            .map { BeanRatingPoint(date: $0.date, rating: $0.rating) }
    }

    var averageRating: Double? {
        let rated = ratedShots
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
    }
}

extension Bean {
    /// Name used when the Log screen's bean prompt is left blank.
    static let unknownName = "Unknown"

    /// A bean created on the fly when a shot is saved before any bean exists.
    /// Only the name is known: roaster, roast and process stay blank until
    /// the user fills them in on the bean page. A blank name becomes
    /// "Unknown", and an "Unknown" bean is marked as a placeholder.
    static func quickAdd(name rawName: String, bagNumber: Int) -> Bean {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? unknownName : trimmed
        let bean = Bean(
            name: name,
            bagNumber: bagNumber,
            roaster: "",
            singleOrigin: false,
            process: .other,
            roast: .medium
        )
        bean.processRaw = ""
        bean.roastRaw = ""
        bean.isPlaceholder = name.caseInsensitiveCompare(unknownName) == .orderedSame
        return bean
    }
}
