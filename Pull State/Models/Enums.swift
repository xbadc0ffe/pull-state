import Foundation

enum Extraction: String, CaseIterable, Codable, Identifiable {
    case sour = "Sour"
    case perfect = "Perfect"
    case bitter = "Bitter"

    var id: String { rawValue }
}

enum Roast: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case medium = "Medium"
    case dark = "Dark"

    var id: String { rawValue }
}

enum BeanProcess: String, CaseIterable, Codable, Identifiable {
    case washed = "Washed"
    case natural = "Natural"
    case honey = "Honey"
    case wetHulled = "Wet Hulled"
    case other = "Other"

    var id: String { rawValue }
}

enum EquipmentKind: String, Codable, CaseIterable, Identifiable {
    case machine
    case grinder

    var id: String { rawValue }
    var addLabel: String { self == .machine ? "Add Machine" : "Add Grinder" }
    var sectionTitle: String { self == .machine ? "Espresso Machines" : "Grinders" }
    var singular: String { self == .machine ? "Machine" : "Grinder" }
    var defaultName: String { self == .machine ? "New Machine" : "New Grinder" }
    var examplePlaceholder: String { self == .machine ? "Linea Mini" : "Niche Zero" }
    var exampleBrandPlaceholder: String { self == .machine ? "La Marzocco" : "Niche" }
}

enum TastingTag: String, CaseIterable, Codable, Identifiable {
    case acidic = "Acidic"
    case bitter = "Bitter"
    case sour = "Sour"
    case sweet = "Sweet"
    case smoky = "Smoky"
    case nutty = "Nutty"
    case floral = "Floral"
    case perfect = "Perfect"

    var id: String { rawValue }
}

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
