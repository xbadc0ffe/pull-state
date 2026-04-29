import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Installs a global observer that selects all text on every text-field /
/// text-view focus, so a tap-to-edit immediately replaces the existing value.
enum SelectAllOnFocus {
    #if canImport(UIKit)
    private static var installed = false
    private static var fieldToken: NSObjectProtocol?
    private static var viewToken: NSObjectProtocol?
    #endif

    @MainActor
    static func install() {
        #if canImport(UIKit)
        guard !installed else { return }
        installed = true
        fieldToken = NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let tf = note.object as? UITextField, tf.text?.isEmpty == false else { return }
            DispatchQueue.main.async { tf.selectAll(nil) }
        }
        viewToken = NotificationCenter.default.addObserver(
            forName: UITextView.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let tv = note.object as? UITextView, !tv.text.isEmpty else { return }
            DispatchQueue.main.async { tv.selectAll(nil) }
        }
        #endif
    }
}
