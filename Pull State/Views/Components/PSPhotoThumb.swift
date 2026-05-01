import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Square photo thumbnail used in list rows and pickers. Shows the decoded
/// `UIImage` when `data` is non-nil and falls back to `PSPlaceholder` so empty
/// slots stay visually consistent with the rest of the app.
struct PSPhotoThumb: View {
    let data: Data?
    var label: String? = nil
    var radius: CGFloat = 10

    var body: some View {
        // The slot is square; the image fits inside it (scaledToFit), so
        // landscape and portrait photos sit as a centered rectangle with
        // transparent space around them — and never overflow into the row's
        // text. PSPlaceholder fills the whole slot when no photo is set.
        ZStack {
            #if canImport(UIKit)
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PSPlaceholder(label: label, radius: radius)
            }
            #else
            PSPlaceholder(label: label, radius: radius)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
