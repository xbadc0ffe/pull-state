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

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius, fahrenheit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius:    return "°C"
        case .fahrenheit: return "°F"
        }
    }

    var pickerLabel: String {
        switch self {
        case .celsius:    return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }

    func display(celsius c: Double) -> Double {
        self == .celsius ? c : c * 9.0/5.0 + 32.0
    }

    func toCelsius(_ value: Double) -> Double {
        self == .celsius ? value : (value - 32.0) * 5.0/9.0
    }
}

@Model
final class AppSettings {
    var appearanceRaw: String
    var temperatureUnitRaw: String = "celsius"
    var hasCompletedOnboarding: Bool
    var hasTipped: Bool
    var nextBagNumber: Int
    var seedDataInstalled: Bool

    init(
        appearance: AppearanceMode = .system,
        temperatureUnit: TemperatureUnit = .celsius,
        hasCompletedOnboarding: Bool = false,
        hasTipped: Bool = false,
        nextBagNumber: Int = 1,
        seedDataInstalled: Bool = false
    ) {
        self.appearanceRaw = appearance.rawValue
        self.temperatureUnitRaw = temperatureUnit.rawValue
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasTipped = hasTipped
        self.nextBagNumber = nextBagNumber
        self.seedDataInstalled = seedDataInstalled
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var temperatureUnit: TemperatureUnit {
        get { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius }
        set { temperatureUnitRaw = newValue.rawValue }
    }
}
