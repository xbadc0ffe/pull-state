import SwiftUI
#if canImport(UIKit)
import UIKit

// Keep the interactive swipe-from-edge pop gesture alive even when the
// navigation bar is hidden via .toolbar(.hidden, for: .navigationBar).
// Without this, UINavigationController disables the gesture whenever the
// bar is hidden because the back button is its default trigger.
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
