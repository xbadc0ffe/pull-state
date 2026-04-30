import SwiftUI
import SwiftData

@main
struct Pull_StateApp: App {
    let container: ModelContainer

    init() {
        // Ensure Application Support exists before SwiftData touches it.
        // On a fresh install the directory doesn't exist yet; SwiftData will
        // auto-recover, but only after spamming a multi-screen CoreData
        // diagnostic dump to the console.
        _ = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        do {
            let schema = Schema([
                Shot.self, Bean.self, Equipment.self, AppSettings.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        SelectAllOnFocus.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
