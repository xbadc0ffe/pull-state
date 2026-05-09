import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Square photo thumbnail used in list rows and pickers. Shows the decoded
/// `UIImage` when `data` is non-nil; if nil, optionally tries `fallback`; if
/// that's also nil, falls back to `PSPlaceholder` so empty slots stay visually
/// consistent with the rest of the app.
struct PSPhotoThumb: View {
    let data: Data?
    var label: String? = nil
    var radius: CGFloat = 10
    var fallback: Data? = nil

    var body: some View {
        // The slot is square; the image fits inside it (scaledToFit), so
        // landscape and portrait photos sit as a centered rectangle with
        // transparent space around them — and never overflow into the row's
        // text. PSPlaceholder fills the whole slot when neither data nor
        // fallback yields a decodable image.
        ZStack {
            #if canImport(UIKit)
            if let img = decodedImage(data) ?? decodedImage(fallback) {
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

    #if canImport(UIKit)
    private func decodedImage(_ data: Data?) -> UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
    #endif
}
