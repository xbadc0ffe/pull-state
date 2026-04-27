import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func installIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        if (try? context.fetch(descriptor))?.first != nil { return }
        let settings = AppSettings(seedDataInstalled: true)
        context.insert(settings)
        try? context.save()
    }
}
