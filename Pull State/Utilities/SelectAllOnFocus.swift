// SelectAllOnFocus.swift
//
// Intentional UIKit exception. SwiftUI offers no built-in modifier that says
// "when this field gains focus, pre-select its existing content." Pull State
// has many numeric fields (dose, yield, temperature, pressure, grind setting,
// timer values) where a tap-to-replace flow is much faster than the default
// tap-to-append behaviour. Implementing this view-by-view in SwiftUI would
// require a UIViewRepresentable wrapper around UITextField; instead, this
// utility hooks the system-wide text-field notification once at app launch
// and applies `selectAll(_:)` to the field that just became first responder.
//
// Only single-line `UITextField`s are affected. Multi-line `UITextView`s (the
// Notes editors on shots and beans) are deliberately left alone: selecting a
// whole note on focus would make the first keystroke erase it.
//
// `install()` is called from `Pull_StateApp.init()` and is idempotent — repeat
// calls are no-ops. The observer stays alive for the entire app lifetime.
import Foundation
import UIKit

/// Installs a global observer that selects all text on every single-line
/// text-field focus, so a tap-to-edit immediately replaces the existing value.
enum SelectAllOnFocus {
    private static var installed = false
    private static var fieldToken: NSObjectProtocol?

    @MainActor
    static func install() {
        guard !installed else { return }
        installed = true
        fieldToken = NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { note in
            // The observer runs on `.main`, but the closure is typed as
            // Sendable so the compiler can't see that; hop explicitly.
            guard let tf = note.object as? UITextField else { return }
            MainActor.assumeIsolated {
                guard tf.text?.isEmpty == false else { return }
                DispatchQueue.main.async { tf.selectAll(nil) }
            }
        }
    }
}
