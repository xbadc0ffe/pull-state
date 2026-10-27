import SwiftUI
import UIKit

/// Square photo thumbnail used in list rows, pickers and detail-screen hero
/// slots. Shows the decoded image when `data` is non-nil; if nil, optionally
/// tries `fallback`; if that's also nil, falls back to `PSPlaceholder` so
/// empty slots stay visually consistent with the rest of the app.
///
/// Decoding goes through `PSThumbnailCache`: off the main actor, downsampled
/// to `maxPixels`, and cached, so a History list of photographed shots never
/// decodes full-size JPEGs on the main thread. Cache hits paint synchronously;
/// misses show the placeholder for one frame while the decode runs.
struct PSPhotoThumb: View {
    let data: Data?
    var label: String? = nil
    var radius: CGFloat = 10
    var fallback: Data? = nil
    /// Pass `true` for the full-width square hero on detail screens.
    var hero: Bool = false

    @State private var decoded: UIImage? = nil

    private var maxPixels: CGFloat { hero ? PSThumbnailCache.heroPixels : PSThumbnailCache.thumbPixels }

    private var image: UIImage? {
        PSThumbnailCache.shared.cached(data, maxPixels: maxPixels)
            ?? PSThumbnailCache.shared.cached(fallback, maxPixels: maxPixels)
            ?? decoded
    }

    var body: some View {
        // The slot is square; the image fits inside it (scaledToFit), so any
        // legacy non-square photo sits as a centered rectangle with
        // transparent space around it — and never overflows into the row's
        // text. PSPlaceholder fills the whole slot when neither data nor
        // fallback yields a decodable image.
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PSPlaceholder(label: label, radius: radius)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: TaskKey(data: data, fallback: fallback, hero: hero)) {
            decoded = nil
            if let primary = await PSThumbnailCache.shared.image(for: data, maxPixels: maxPixels) {
                decoded = primary
            } else {
                decoded = await PSThumbnailCache.shared.image(for: fallback, maxPixels: maxPixels)
            }
        }
    }

    private struct TaskKey: Equatable {
        let data: Data?
        let fallback: Data?
        let hero: Bool
    }
}
