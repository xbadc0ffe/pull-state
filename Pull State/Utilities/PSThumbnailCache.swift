// PSThumbnailCache.swift
//
// Decoding a multi-megabyte JPEG with `UIImage(data:)` on the main thread for
// every 32–78 pt thumbnail is the single biggest scroll-jank risk in the app.
// This cache decodes photos off the main actor with ImageIO's downsampling
// path (which never materialises the full-size bitmap) and keeps the result
// in an `NSCache` keyed by the photo bytes' hash plus the requested size.
import Foundation
import ImageIO
import UIKit

/// Off-main, size-bounded photo decoder with an in-memory cache.
/// `PSPhotoThumb` is the only client; see that file for the display side.
final class PSThumbnailCache: Sendable {
    static let shared = PSThumbnailCache()

    /// Longest edge, in pixels, for list/picker thumbnails (covers 78 pt @3x).
    static let thumbPixels: CGFloat = 320
    /// Longest edge for the square hero photo on detail screens (560 pt @3x).
    static let heroPixels: CGFloat = 1700

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()

    private init() {}

    private func key(for data: Data, maxPixels: CGFloat) -> NSString {
        var hasher = Hasher()
        hasher.combine(data)
        return "\(hasher.finalize())-\(Int(maxPixels))" as NSString
    }

    /// Synchronous cache lookup for first paint; nil means "not decoded yet".
    func cached(_ data: Data?, maxPixels: CGFloat) -> UIImage? {
        guard let data else { return nil }
        return cache.object(forKey: key(for: data, maxPixels: maxPixels))
    }

    /// Decodes (downsampled) off the main actor and caches the result.
    func image(for data: Data?, maxPixels: CGFloat) async -> UIImage? {
        guard let data else { return nil }
        let k = key(for: data, maxPixels: maxPixels)
        if let hit = cache.object(forKey: k) { return hit }
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.downsample(data, maxPixels: maxPixels)
        }.value
        if let decoded { cache.setObject(decoded, forKey: k) }
        return decoded
    }

    /// ImageIO downsample: honours EXIF orientation and never decodes the
    /// full-resolution bitmap into memory.
    nonisolated static func downsample(_ data: Data, maxPixels: CGFloat) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
