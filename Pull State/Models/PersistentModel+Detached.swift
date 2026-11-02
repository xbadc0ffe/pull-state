import SwiftData

extension PersistentModel {
    /// True once this model has been deleted and the deletion saved.
    ///
    /// SwiftUI can redraw a view that still holds such a model one last time
    /// before its list drops it: a card while Wipe Data runs, or the Hardware
    /// tab's card for a machine just deleted from its detail page. Ordinary
    /// attributes still return their last values then, but photos live in
    /// external storage and are loaded lazily, and loading one for a deleted
    /// model is a fatal SwiftData error ("backing data was detached from a
    /// context without resolving attribute faults"; the Wipe Data crash in
    /// 1.5 build 202610302343). Views therefore read photos through each
    /// model's `photo`, which checks this first.
    nonisolated var isDetached: Bool { modelContext == nil }
}
