import Foundation
import SwiftData

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

@Model
final class AppSettings {
    var appearanceRaw: String
    var hasCompletedOnboarding: Bool
    var hasTipped: Bool
    var nextBagNumber: Int
    var seedDataInstalled: Bool

    init(
        appearance: AppearanceMode = .system,
        hasCompletedOnboarding: Bool = false,
        hasTipped: Bool = false,
        nextBagNumber: Int = 1,
        seedDataInstalled: Bool = false
    ) {
        self.appearanceRaw = appearance.rawValue
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasTipped = hasTipped
        self.nextBagNumber = nextBagNumber
        self.seedDataInstalled = seedDataInstalled
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
}
