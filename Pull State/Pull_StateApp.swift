import SwiftUI
import SwiftData

@main
struct Pull_StateApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Shot.self, Bean.self, Equipment.self, AppSettings.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
