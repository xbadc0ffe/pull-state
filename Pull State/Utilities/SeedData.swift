// SeedData.swift
//
// SwiftData equivalent of "create the singleton settings row on first launch."
// The whole app stores user-tunable preferences (appearance, temperature unit,
// onboarding completion, monotonic bag counter, tip-jar state) on a single
// `AppSettings` model instance. SwiftData has no concept of a default row, so
// `RootView.task` calls into here on every appear; if the AppSettings table is
// empty we insert the singleton, otherwise we no-op.
//
// The name is historical — there is no demo seed data. The app starts truly
// empty: zero beans, zero hardware, zero shots. Bag #1 is the first bag the
// user adds.
import Foundation
import SwiftData

/// Creates the singleton `AppSettings` row on first launch and never again.
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
