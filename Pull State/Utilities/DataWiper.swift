// DataWiper.swift
//
// About → Wipe Data. The user first picks a scope, then confirms twice; the
// sheet calls `DataWiper.wipe` only after the second confirmation. Models are
// fetched and deleted one by one (not a batch delete) so SwiftData applies
// the relationship rules and removes external-storage photos with them.
import Foundation
import SwiftData

/// How much About → Wipe Data deletes.
enum WipeScope: CaseIterable, Identifiable {
    /// Every shot and shot photo. Beans, recipes, hardware and settings stay.
    case shots
    /// Shots, beans and hardware. Settings stay; bag numbers restart at #1.
    case library
    /// Everything, settings included; the app returns to onboarding.
    case everything

    var id: Self { self }

    /// Button title in the scope chooser.
    var title: String {
        switch self {
        case .shots:      return "Shots only"
        case .library:    return "Shots, beans & hardware"
        case .everything: return "Everything (full reset)"
        }
    }

    /// Label of the final, destructive confirmation button.
    var confirmLabel: String {
        switch self {
        case .shots:      return "Wipe Shots"
        case .library:    return "Wipe Data"
        case .everything: return "Reset Everything"
        }
    }

    /// Shown under the Wipe button once the wipe is done (not used for
    /// `.everything`, which closes the sheet and restarts onboarding).
    var doneMessage: String {
        switch self {
        case .shots:      return "Shot history wiped."
        case .library:    return "Shots, beans and hardware wiped."
        case .everything: return "Everything was reset."
        }
    }
}

enum DataWiper {
    /// Deletes what `scope` covers and saves. `.library` also restarts the
    /// bag counter at #1; `.everything` additionally resets every setting
    /// and flips `hasCompletedOnboarding` off, which sends `RootView` back
    /// to onboarding. (The tip-jar state is re-derived from StoreKit the
    /// next time About opens, so resetting `hasTipped` loses nothing.)
    static func wipe(_ scope: WipeScope, in context: ModelContext, settings: AppSettings?) throws {
        try deleteAll(Shot.self, in: context)
        if scope != .shots {
            try deleteAll(Bean.self, in: context)
            try deleteAll(Equipment.self, in: context)
            settings?.nextBagNumber = 1
        }
        if scope == .everything, let settings {
            settings.appearance = .system
            settings.temperatureUnit = .celsius
            settings.autoRecipePromptEnabled = true
            settings.hasTipped = false
            settings.hasCompletedOnboarding = false
        }
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
