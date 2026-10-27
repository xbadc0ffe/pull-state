// SwipeBackFix.swift
//
// Intentional UIKit exception. SwiftUI's `.toolbar(.hidden, for: .navigationBar)`
// hides the system back button, and `UINavigationController` reacts by also
// disabling the interactive swipe-from-edge pop gesture (the back button is the
// gesture's default trigger). Pull State's detail screens hide the toolbar to
// render their own `PSNavBar`, so without this shim the swipe-back gesture
// would silently die on every detail view.
//
// The fix retroactively adopts `UIGestureRecognizerDelegate` on
// `UINavigationController` and re-enables the gesture when the stack has more
// than one controller. Two guards keep it narrow:
//   • it skips `UIImagePickerController` (the camera path) so system pickers
//     keep their own gesture behaviour;
//   • it refuses to begin while a push/pop transition is in flight
//     (`transitionCoordinator != nil`) — swiping mid-transition is the classic
//     way to corrupt a navigation stack.
//
// Overriding `viewDidLoad` from an extension is only possible because the
// method is `@objc`; Swift does not formally support it. If a future SDK
// rejects this, replace the shim with a `UIViewControllerRepresentable` that
// walks up to its navigation controller and sets the delegate there.
//
// Note: never combine the toolbar-hidden approach with
// `.navigationBarBackButtonHidden(true)` — that modifier kills the gesture for
// a different reason that this shim does not address.
import SwiftUI
import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        guard !(self is UIImagePickerController) else { return }
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}
