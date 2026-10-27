import Foundation
import Testing
@testable import Pull_State

struct RecipeCodableTests {
    @Test func roundTripsEveryField() throws {
        let r = Recipe(grind: "22", dose: 18, yield: 36, temp: 93.5, preInfTime: 8, preInfPressure: 1.5, pullTime: 28, pullPressure: 9)
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(back == r)
    }

    @Test func missingKeysDecodeToNil() throws {
        // A record written before `preInfPressure` existed.
        let json = #"{"dose":18,"yield":36}"#.data(using: .utf8)!
        let r = try JSONDecoder().decode(Recipe.self, from: json)
        #expect(r.dose == 18)
        #expect(r.yield == 36)
        #expect(r.temp == nil)
        #expect(r.preInfPressure == nil)
        #expect(r.grind == nil)
    }

    @Test func emptyRecipeIsAllNil() {
        #expect(Recipe() == Recipe(grind: nil, dose: nil, yield: nil, temp: nil, preInfTime: nil, preInfPressure: nil, pullTime: nil, pullPressure: nil))
    }
}

struct TemperatureUnitTests {
    @Test func celsiusIsIdentity() {
        #expect(TemperatureUnit.celsius.display(celsius: 93) == 93)
        #expect(TemperatureUnit.celsius.toCelsius(93) == 93)
    }

    @Test func fahrenheitConvertsBothWays() {
        #expect(abs(TemperatureUnit.fahrenheit.display(celsius: 100) - 212) < 1e-9)
        #expect(abs(TemperatureUnit.fahrenheit.toCelsius(32) - 0) < 1e-9)
        let c = 93.0
        #expect(abs(TemperatureUnit.fahrenheit.toCelsius(TemperatureUnit.fahrenheit.display(celsius: c)) - c) < 1e-9)
    }

    @Test func unknownRawValueFallsBackToCelsius() {
        let s = AppSettings()
        s.temperatureUnitRaw = "kelvin"
        #expect(s.temperatureUnit == .celsius)
    }
}

struct HardwareCatalogTests {
    @Test func brandLookupMatchesExactName() {
        #expect(HardwareCatalog.brand(forName: "Flair 58", kind: .machine) == "Flair Espresso")
        #expect(HardwareCatalog.brand(forName: "J-Ultra", kind: .grinder) == "1Zpresso")
        #expect(HardwareCatalog.brand(forName: "J-Ultra", kind: .machine) == nil)
        #expect(HardwareCatalog.brand(forName: "Not A Grinder", kind: .grinder) == nil)
    }

    @Test func catalogHasNoDuplicateIDs() {
        for kind in EquipmentKind.allCases {
            let ids = HardwareCatalog.entries(for: kind).map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }
}

struct FormatterTests {
    @Test func secondsFormatting() {
        #expect(PSFmt.seconds(0) == "0.0s")
        #expect(PSFmt.seconds(27.04) == "27.0s")
        #expect(PSFmt.seconds(60) == "1:00.0")
        #expect(PSFmt.seconds(95.5) == "1:35.5")
        #expect(PSFmt.seconds(.nan) == "0.0s")
    }

    @Test func numberFormatting() {
        #expect(PSFmt.number(18) == "18")
        #expect(PSFmt.number(18.5) == "18.5")
        #expect(PSFmt.number(18.04) == "18.0")
        #expect(PSFmt.number(.infinity) == "—")
    }

    @Test func fixedDatePatterns() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 10; comps.day = 27; comps.hour = 8; comps.minute = 5; comps.second = 9
        let date = Calendar.current.date(from: comps)!
        #expect(PSFmt.shortDate(date) == "2026-10-27")
        #expect(PSFmt.shortDateMono(date) == "10-27")
        #expect(PSFmt.cardDate(date) == "2026-10-27 08:05")
        #expect(PSFmt.detailDate(date) == "2026-10-27 · 08:05:09")
    }
}

struct ShotAndBeanTests {
    @Test func ratioGuardsZeroDose() {
        let s = Shot(dose: 0, yield: 36)
        #expect(s.ratio == 0)
        #expect(Shot(dose: 18, yield: 36).ratio == 2)
    }

    @Test func unknownTagsAreDropped() {
        let s = Shot()
        s.tagsRaw = ["chocolate", "acidic", "fruity"]
        #expect(s.tags == [.chocolate, .fruity])
    }

    @Test func processDisplayUsesOtherText() {
        let b = Bean(name: "X", bagNumber: 1, roaster: "Y", singleOrigin: true, process: .other, processOther: "Anaerobic", roast: .light)
        #expect(b.processDisplay == "Anaerobic")
        b.processOther = ""
        #expect(b.processDisplay == "Other")
        b.process = .washed
        #expect(b.processDisplay == "Washed")
    }
}
