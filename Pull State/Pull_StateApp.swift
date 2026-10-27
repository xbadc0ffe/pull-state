import SwiftUI
import SwiftData

/// App entry point. Bootstraps the SwiftData `ModelContainer` (with a
/// recovery path for an unopenable store), creates the app-wide
/// `StoreManager`, installs the global select-all-on-focus observer, and
/// hands off to `RootView`.
@main
struct Pull_StateApp: App {
    let container: ModelContainer
    /// True when the on-disk store could not be opened and was moved aside;
    /// `RootView` shows a one-time notice so the empty state isn't a mystery.
    let recoveredFromCorruptStore: Bool

    @State private var store = StoreManager()

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

        let result = Self.makeContainer()
        container = result.container
        recoveredFromCorruptStore = result.recovered
        SelectAllOnFocus.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView(recoveredFromCorruptStore: recoveredFromCorruptStore)
                .environment(store)
        }
        .modelContainer(container)
    }

    /// Opens the persistent store. If that fails (corruption, an impossible
    /// migration), the store files are moved to a timestamped sibling folder
    /// and a fresh store is created — a launch crash loop is worse than an
    /// empty logbook, and the old files stay on disk for manual recovery. As
    /// a last resort the app runs in memory for this session.
    private static func makeContainer() -> (container: ModelContainer, recovered: Bool) {
        let schema = Schema([Shot.self, Bean.self, Equipment.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return (container, false)
        }

        moveAsideStoreFiles(at: config.url)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return (container, true)
        }

        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return (try ModelContainer(for: schema, configurations: [memory]), true)
        } catch {
            // An in-memory container has no I/O to fail on; if even this
            // throws, the schema itself is broken and there is nothing to run.
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }

    private static func moveAsideStoreFiles(at url: URL) {
        let fm = FileManager.default
        let stamp = Int(Date.now.timeIntervalSince1970)
        let backupDir = url.deletingLastPathComponent().appendingPathComponent("Unreadable-\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let base = url.lastPathComponent
        for suffix in ["", "-shm", "-wal"] {
            let src = url.deletingLastPathComponent().appendingPathComponent(base + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            try? fm.moveItem(at: src, to: backupDir.appendingPathComponent(base + suffix))
        }
        // External-storage blobs live beside the store in a hidden folder.
        let external = url.deletingLastPathComponent().appendingPathComponent(".\(base)_SUPPORT", isDirectory: true)
        if fm.fileExists(atPath: external.path) {
            try? fm.moveItem(at: external, to: backupDir.appendingPathComponent(".\(base)_SUPPORT"))
        }
    }
}
