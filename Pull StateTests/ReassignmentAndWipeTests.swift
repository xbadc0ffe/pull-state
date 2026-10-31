import Foundation
import SwiftData
import Testing
@testable import Pull_State

/// Quick-added beans, moving shots between beans and hardware, and the
/// "Unknown" clean-up. Runs against an in-memory store so relationship rules
/// (inverses, cascade, nullify) behave exactly as in the app.
struct ShotReassignmentTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Shot.self, Bean.self, Equipment.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func fullBean(_ name: String, bag: Int) -> Bean {
        Bean(name: name, bagNumber: bag, roaster: "Onyx", singleOrigin: true, process: .washed, roast: .light)
    }

    private func beanNames() throws -> [String] {
        try context.fetch(FetchDescriptor<Bean>()).map(\.name).sorted()
    }

    @Test func quickAddWithBlankNameIsAnUnknownPlaceholder() {
        let bean = Bean.quickAdd(name: "   ", bagNumber: 4)
        #expect(bean.name == "Unknown")
        #expect(bean.isPlaceholder)
        #expect(bean.bagNumber == 4)
        #expect(bean.roaster.isEmpty)
        #expect(bean.roastIfSet == nil)
        #expect(bean.processIfSet == nil)
        #expect(!bean.singleOrigin)
        #expect(bean.recipe.isEmpty)
        #expect(bean.pickerSubtitle == "#4")
    }

    @Test func quickAddWithANameIsARealBean() {
        let bean = Bean.quickAdd(name: "  Ethiopia Guji ", bagNumber: 1)
        #expect(bean.name == "Ethiopia Guji")
        #expect(!bean.isPlaceholder)
        #expect(Bean.quickAdd(name: "unknown", bagNumber: 2).isPlaceholder)
        #expect(fullBean("Black Gold", bag: 3).pickerSubtitle == "Onyx · #3")
    }

    @Test func movingTheLastShotRemovesOnlyTheEmptyPlaceholder() throws {
        let unknown = Bean.quickAdd(name: "", bagNumber: 1)
        let named = Bean.quickAdd(name: "Guji", bagNumber: 2)
        let target = fullBean("Black Gold", bag: 3)
        for bean in [unknown, named, target] { context.insert(bean) }
        let first = Shot(bean: unknown)
        let second = Shot(bean: unknown)
        let third = Shot(bean: named)
        for shot in [first, second, third] { context.insert(shot) }
        try context.save()

        // One of two shots moves: the placeholder still has a shot.
        ShotReassignment.apply(bean: target, machine: .keep, grinder: .keep, to: [first], in: context)
        #expect(try beanNames() == ["Black Gold", "Guji", "Unknown"])

        // The last one moves: "Unknown" goes, the emptied named bean stays.
        ShotReassignment.apply(bean: target, machine: .keep, grinder: .keep, to: [second, third], in: context)
        #expect(try beanNames() == ["Black Gold", "Guji"])
        #expect(target.shots.count == 3)
    }

    @Test func anEditedPlaceholderIsKept() throws {
        let unknown = Bean.quickAdd(name: "", bagNumber: 1)
        let target = fullBean("Black Gold", bag: 2)
        context.insert(unknown)
        context.insert(target)
        let shot = Shot(bean: unknown)
        context.insert(shot)
        try context.save()

        unknown.isPlaceholder = false // what saving an edit on the bean page does
        ShotReassignment.apply(bean: target, machine: .keep, grinder: .keep, to: [shot], in: context)
        #expect(try beanNames() == ["Black Gold", "Unknown"])
    }

    @Test func hardwareChoicesSetClearOrKeep() throws {
        let flair = Equipment(name: "Flair 58", brand: "Flair", kind: .machine)
        let robot = Equipment(name: "Robot", brand: "Cafelat", kind: .machine)
        let grinder = Equipment(name: "J-Ultra", brand: "1Zpresso", kind: .grinder)
        let bean = fullBean("Black Gold", bag: 1)
        for item in [flair, robot, grinder] { context.insert(item) }
        context.insert(bean)
        let shot = Shot(bean: bean, machine: flair, grinder: grinder)
        context.insert(shot)
        try context.save()

        ShotReassignment.apply(bean: nil, machine: .set(robot), grinder: .keep, to: [shot], in: context)
        #expect(shot.machine?.name == "Robot")
        #expect(shot.grinder?.name == "J-Ultra")
        #expect(shot.bean?.name == "Black Gold")

        ShotReassignment.apply(bean: nil, machine: .keep, grinder: .clear, to: [shot], in: context)
        #expect(shot.machine?.name == "Robot")
        #expect(shot.grinder == nil)
        #expect(flair.shotCount == 0)
        #expect(robot.shotCount == 1)
    }

    @Test func backfillFillsOnlyShotsWithoutHardware() throws {
        let bean = fullBean("Black Gold", bag: 1)
        let old = Equipment(name: "Old", brand: "", kind: .machine)
        context.insert(bean)
        context.insert(old)
        let bare1 = Shot(bean: bean)
        let bare2 = Shot(bean: bean)
        let owned = Shot(bean: bean, machine: old)
        for shot in [bare1, bare2, owned] { context.insert(shot) }
        try context.save()

        #expect(ShotReassignment.shotsMissing(.machine, in: context).count == 2)
        #expect(ShotReassignment.shotsMissing(.grinder, in: context).count == 3)

        let flair = Equipment(name: "Flair 58", brand: "Flair", kind: .machine)
        context.insert(flair)
        try context.save()
        ShotReassignment.backfill(flair, in: context)

        #expect(bare1.machine?.name == "Flair 58")
        #expect(bare2.machine?.name == "Flair 58")
        #expect(owned.machine?.name == "Old")
        #expect(ShotReassignment.shotsMissing(.machine, in: context).isEmpty)
    }
}

/// About → Wipe Data, one test per scope.
struct DataWiperTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Shot.self, Bean.self, Equipment.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func seed() throws -> AppSettings {
        let settings = AppSettings(
            appearance: .dark, temperatureUnit: .fahrenheit, hasCompletedOnboarding: true,
            hasTipped: true, nextBagNumber: 5, autoRecipePromptEnabled: false
        )
        let bean = Bean(name: "Black Gold", bagNumber: 4, roaster: "Onyx", singleOrigin: true, process: .washed, roast: .light)
        let machine = Equipment(name: "Flair 58", brand: "Flair", kind: .machine)
        context.insert(settings)
        context.insert(bean)
        context.insert(machine)
        context.insert(Shot(bean: bean, machine: machine))
        context.insert(Shot(bean: bean))
        try context.save()
        return settings
    }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test func shotsOnlyKeepsTheLibraryAndSettings() throws {
        let settings = try seed()
        try DataWiper.wipe(.shots, in: context, settings: settings)
        #expect(try count(Shot.self) == 0)
        #expect(try count(Bean.self) == 1)
        #expect(try count(Equipment.self) == 1)
        #expect(settings.nextBagNumber == 5)
        #expect(settings.hasCompletedOnboarding)
        #expect(settings.temperatureUnit == .fahrenheit)
    }

    @Test func libraryWipeRestartsBagNumbersAndKeepsSettings() throws {
        let settings = try seed()
        try DataWiper.wipe(.library, in: context, settings: settings)
        #expect(try count(Shot.self) == 0)
        #expect(try count(Bean.self) == 0)
        #expect(try count(Equipment.self) == 0)
        #expect(try count(AppSettings.self) == 1)
        #expect(settings.nextBagNumber == 1)
        #expect(settings.hasCompletedOnboarding)
        #expect(settings.appearance == .dark)
        #expect(settings.temperatureUnit == .fahrenheit)
    }

    @Test func everythingResetsSettingsAndReturnsToOnboarding() throws {
        let settings = try seed()
        try DataWiper.wipe(.everything, in: context, settings: settings)
        #expect(try count(Shot.self) == 0)
        #expect(try count(Bean.self) == 0)
        #expect(try count(Equipment.self) == 0)
        #expect(try count(AppSettings.self) == 1)
        #expect(settings.nextBagNumber == 1)
        #expect(!settings.hasCompletedOnboarding)
        #expect(settings.appearance == .system)
        #expect(settings.temperatureUnit == .celsius)
        #expect(settings.autoRecipePromptEnabled)
        #expect(!settings.hasTipped)
    }
}
