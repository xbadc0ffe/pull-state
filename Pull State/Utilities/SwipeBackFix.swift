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
// `UINavigationController` and re-enables the gesture whenever the stack has
// more than one controller. There is no SwiftUI-native equivalent in iOS 18.
//
// Note: never combine the toolbar-hidden approach with
// `.navigationBarBackButtonHidden(true)` — that modifier kills the gesture for
// a different reason that this shim does not address.
import SwiftUI
#if canImport(UIKit)
import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif
