import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Pull_State

/// Deleting while the real UI is on screen. 1.5 build 202610302343 crashed
/// on About → Wipe Data → Everything: after the delete, SwiftUI redrew a
/// Hardware card one last time and it read the photo of the deleted machine
/// ("This backing data was detached from a context without resolving
/// attribute faults … \Equipment.photoData"). Photos are external storage,
/// loaded lazily, and can't be loaded once the model is gone; views now read
/// them through `photo`, which checks `isDetached`.
///
/// Each test shows `RootView` in a window over an on-disk store whose shots,
/// beans and hardware all have photos (an in-memory store doesn't crash),
/// then deletes the way the app does. A regression crashes the test host.
@MainActor
@Suite(.serialized)
struct LiveDeleteTests {
    private struct Fixture {
        let folder: URL
        let container: ModelContainer
        let settings: AppSettings
        let machine: Equipment
        let bean: Bean
        let shot: Shot
        var context: ModelContext { container.mainContext }

        func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
            try context.fetchCount(FetchDescriptor<T>())
        }
    }

    enum Target: CaseIterable, Sendable { case machine, bean, shot }

    /// Large enough for SwiftData to store it as an external file.
    private func photo(_ byte: UInt8) -> Data { Data(repeating: byte, count: 300_000) }

    private func makeFixture() throws -> Fixture {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "LiveDeleteTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let schema = Schema([Shot.self, Bean.self, Equipment.self, AppSettings.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: folder.appending(path: "store.sqlite"))
        )
        let context = container.mainContext
        let settings = AppSettings(appearance: .dark, temperatureUnit: .fahrenheit, hasCompletedOnboarding: true, nextBagNumber: 2)
        let machine = Equipment(name: "Flair 58", brand: "Flair", kind: .machine, photoData: photo(0xAB))
        let grinder = Equipment(name: "J-Ultra", brand: "1Zpresso", kind: .grinder, photoData: photo(0xCD))
        let bean = Bean(name: "Black Gold", bagNumber: 1, roaster: "Onyx", singleOrigin: true, process: .washed, roast: .light)
        bean.photoData = photo(0xEF)
        let shot = Shot(bean: bean, machine: machine, grinder: grinder, grindSetting: "22")
        shot.photoData = photo(0x12)
        context.insert(settings)
        context.insert(machine)
        context.insert(grinder)
        context.insert(bean)
        context.insert(shot)
        try context.save()
        return Fixture(folder: folder, container: container, settings: settings, machine: machine, bean: bean, shot: shot)
    }

    /// Shows the app's root view for `fixture` in its own window and lets it
    /// settle, so every tab (all four stay mounted) has drawn its cards.
    private func show(_ fixture: Fixture) async throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: RootView().environment(StoreManager()).modelContainer(fixture.container)
        )
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(1))
        return window
    }

    private func close(_ window: UIWindow, _ fixture: Fixture) {
        window.isHidden = true
        try? FileManager.default.removeItem(at: fixture.folder)
    }

    @Test func photoIsNilOnceTheDeletionIsSaved() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.folder) }
        #expect(!fixture.machine.isDetached)
        #expect(fixture.machine.photo == photo(0xAB))

        fixture.context.delete(fixture.machine)
        try fixture.context.save()
        #expect(fixture.machine.isDetached)
        #expect(fixture.machine.photo == nil)
        #expect(fixture.machine.name == "Flair 58")
    }

    @Test(arguments: [WipeScope.shots, WipeScope.library, WipeScope.everything])
    func wipeUnderTheMainScreens(scope: WipeScope) async throws {
        let fixture = try makeFixture()
        let window = try await show(fixture)
        defer { close(window, fixture) }

        try DataWiper.wipe(scope, in: fixture.context, settings: fixture.settings)
        try await Task.sleep(for: .seconds(1))

        #expect(try fixture.count(Shot.self) == 0)
        #expect(try fixture.count(Equipment.self) == (scope == .shots ? 2 : 0))
        #expect(fixture.settings.hasCompletedOnboarding == (scope != .everything))
    }

    /// The detail pages' Delete buttons: delete the way each page does, save,
    /// and the tab list underneath still holds the card. A deleted bean's
    /// shot survives, filed under a new "Unknown" bean. (These never
    /// crashed, even before `photo`; they guard the same path.)
    @Test(arguments: Target.allCases)
    func deletingOneItemUnderTheMainScreens(target: Target) async throws {
        let fixture = try makeFixture()
        let window = try await show(fixture)
        defer { close(window, fixture) }

        switch target {
        case .machine: fixture.context.delete(fixture.machine)
        case .bean: ShotReassignment.deleteBean(fixture.bean, in: fixture.context, settings: fixture.settings)
        case .shot: fixture.context.delete(fixture.shot)
        }
        try fixture.context.save()
        try await Task.sleep(for: .seconds(1))

        #expect(try fixture.count(Equipment.self) == (target == .machine ? 1 : 2))
        #expect(try fixture.count(Shot.self) == (target == .shot ? 0 : 1))
        if target == .bean {
            #expect(fixture.shot.bean?.name == "Unknown")
        }
    }
}
