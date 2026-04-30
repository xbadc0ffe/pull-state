import Foundation

/// User-tagged flavor extraction, single-select. Drives the colored pill on
/// shot cards and the History filter.
enum Extraction: String, CaseIterable, Codable, Identifiable {
    case sour = "Sour"
    case perfect = "Perfect"
    case bitter = "Bitter"

    var id: String { rawValue }
}

/// Bean roast level. Surfaced as a colored pip on `PSRoastBadge`.
enum Roast: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case medium = "Medium"
    case dark = "Dark"

    var id: String { rawValue }
}

/// Bean processing method. `.other` reveals an inline "Specify" text field
/// that writes to `Bean.processOther`.
enum BeanProcess: String, CaseIterable, Codable, Identifiable {
    case washed = "Washed"
    case natural = "Natural"
    case honey = "Honey"
    case wetHulled = "Wet Hulled"
    case other = "Other"

    var id: String { rawValue }
}

/// Discriminator for `Equipment` (one model serves both machines and grinders).
/// Carries kind-specific copy used by the add/edit forms and the Hardware tab.
enum EquipmentKind: String, Codable, CaseIterable, Identifiable {
    case machine
    case grinder

    var id: String { rawValue }
    var addLabel: String { self == .machine ? "Add Machine" : "Add Grinder" }
    var sectionTitle: String { self == .machine ? "Espresso Machines" : "Grinders" }
    var singular: String { self == .machine ? "Machine" : "Grinder" }
    var defaultName: String { self == .machine ? "New Machine" : "New Grinder" }
    var examplePlaceholder: String { self == .machine ? "Flair Pro 3 Updated" : "J-Ultra" }
    var exampleBrandPlaceholder: String { self == .machine ? "Flair Espresso" : "1Zpresso" }
}

/// Closed set of tasting-note tags, multi-select. Persisted as lowercase raw
/// values; `Shot.tags` decodes via `compactMap`, so unknown raw values from
/// older tag-set versions are silently dropped instead of crashing.
enum TastingTag: String, CaseIterable, Codable, Identifiable {
    case chocolate
    case caramel
    case fruity
    case citrus
    case floral
    case nutty
    case smoky
    case earthy

    var id: String { rawValue }

    var label: String { rawValue.capitalized }
}

/// Sort options for the History tab.
enum SortOrder: String, CaseIterable, Identifiable {
    case newest, oldest, highest, lowest

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest:  return "Newest first"
        case .oldest:  return "Oldest first"
        case .highest: return "Highest rated"
        case .lowest:  return "Lowest rated"
        }
    }
}
