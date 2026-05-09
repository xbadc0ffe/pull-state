import Foundation
import SwiftData

/// One logged espresso pull. Holds the dialed-in numbers, the timer results,
/// the user's tasting notes, and optional bean / machine / grinder references.
/// The references are optional so deleting the underlying hardware (which is
/// `.nullify`) leaves the shot data intact in History.
@Model
final class Shot {
    var date: Date
    var grindSetting: String
    var dose: Double
    var yield: Double
    var waterTemp: Double
    var pressure: Double
    var preInfusion: Double
    var pull: Double
    var extractionRaw: String?
    var tagsRaw: [String]
    var rating: Int
    var notes: String
    var usedPaperFilter: Bool = false
    @Attribute(.externalStorage) var photoData: Data?

    var bean: Bean?
    var machine: Equipment?
    var grinder: Equipment?

    init(
        date: Date = .now,
        bean: Bean? = nil,
        machine: Equipment? = nil,
        grinder: Equipment? = nil,
        grindSetting: String = "",
        dose: Double = 18,
        yield: Double = 38,
        waterTemp: Double = 93,
        pressure: Double = 9,
        preInfusion: Double = 0,
        pull: Double = 0,
        extraction: Extraction? = nil,
        tags: [TastingTag] = [],
        rating: Int = 0,
        notes: String = "",
        usedPaperFilter: Bool = false,
        photoData: Data? = nil
    ) {
        self.date = date
        self.bean = bean
        self.machine = machine
        self.grinder = grinder
        self.grindSetting = grindSetting
        self.dose = dose
        self.yield = yield
        self.waterTemp = waterTemp
        self.pressure = pressure
        self.preInfusion = preInfusion
        self.pull = pull
        self.extractionRaw = extraction?.rawValue
        self.tagsRaw = tags.map(\.rawValue)
        self.rating = rating
        self.notes = notes
        self.usedPaperFilter = usedPaperFilter
        self.photoData = photoData
    }

    var hasPhoto: Bool { photoData != nil }

    var extraction: Extraction? {
        get { extractionRaw.flatMap(Extraction.init(rawValue:)) }
        set { extractionRaw = newValue?.rawValue }
    }

    var tags: [TastingTag] {
        get { tagsRaw.compactMap(TastingTag.init(rawValue:)) }
        set { tagsRaw = newValue.map(\.rawValue) }
    }

    var ratio: Double {
        dose > 0 ? yield / dose : 0
    }
}
