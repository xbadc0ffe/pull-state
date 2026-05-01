import SwiftUI
#if canImport(UIKit)
import UIKit

/// Square crop sheet shown after the user picks or captures a photo. The user
/// pans and pinches the image inside a fixed 1:1 outline; on Done we crop the
/// source image down to that square in pixel space and re-encode JPEG.
///
/// Geometry model: at `scale = 1` the image is rendered so its **shorter**
/// edge equals the on-screen crop side, fully covering the outline in one
/// dimension and overflowing in the other. `minScale = 1`; users can zoom up
/// to `maxScale = 6`. Drag offsets are clamped so the outline never escapes
/// the image — keeping the crop fully populated.
struct PSPhotoCropSheet: View {
    let sourceImage: UIImage
    let onCommit: (Data) -> Void
    let onCancel: () -> Void

    @Environment(\.psPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private let maxScale: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let cropSide = max(120, min(canvas.width, canvas.height) - 64)
            let base = baseRenderedSize(for: sourceImage.size, cropSide: cropSide)

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: sourceImage)
                    .resizable()
                    .frame(width: base.width, height: base.height)
                    .scaleEffect(scale * pinch)
                    .offset(
                        x: clampedOffset(offset.width + drag.width, scale: scale * pinch, base: base.width, cropSide: cropSide),
                        y: clampedOffset(offset.height + drag.height, scale: scale * pinch, base: base.height, cropSide: cropSide)
                    )

                cropOverlay(canvas: canvas, cropSide: cropSide)
                    .allowsHitTesting(false)

                VStack {
                    chrome(cropSide: cropSide, base: base)
                    Spacer()
                    Text("Pinch to zoom · Drag to position")
                        .font(PSFont.mono(10.5))
                        .tracking(0.6)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.bottom, 28)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            let proposedX = offset.width + value.translation.width
                            let proposedY = offset.height + value.translation.height
                            offset = CGSize(
                                width: clampedOffset(proposedX, scale: scale, base: base.width, cropSide: cropSide),
                                height: clampedOffset(proposedY, scale: scale, base: base.height, cropSide: cropSide)
                            )
                        },
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = min(maxScale, max(1, scale * value))
                            offset = CGSize(
                                width: clampedOffset(offset.width, scale: scale, base: base.width, cropSide: cropSide),
                                height: clampedOffset(offset.height, scale: scale, base: base.height, cropSide: cropSide)
                            )
                        }
                )
            )
        }
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private func chrome(cropSide: CGFloat, base: CGSize) -> some View {
        HStack {
            Button("Cancel") { onCancel() }
                .foregroundStyle(.white)
                .font(PSFont.body(15, weight: .semibold))

            Spacer()

            Text("Crop photo")
                .foregroundStyle(.white)
                .font(PSFont.display(16, weight: .semibold))

            Spacer()

            Button {
                if let data = makeCroppedData(cropSide: cropSide, base: base) {
                    onCommit(data)
                } else {
                    onCancel()
                }
            } label: {
                Text("Done")
                    .foregroundStyle(.white)
                    .font(PSFont.body(15, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func cropOverlay(canvas: CGSize, cropSide: CGFloat) -> some View {
        let frame = CGRect(
            x: (canvas.width - cropSide) / 2,
            y: (canvas.height - cropSide) / 2,
            width: cropSide,
            height: cropSide
        )
        ZStack {
            Path { p in
                p.addRect(CGRect(origin: .zero, size: canvas))
                p.addRect(frame)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Path { p in p.addRect(frame) }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.25)
        }
    }

    private func baseRenderedSize(for imgSize: CGSize, cropSide: CGFloat) -> CGSize {
        guard imgSize.width > 0, imgSize.height > 0 else {
            return CGSize(width: cropSide, height: cropSide)
        }
        // At scale = 1 the shorter side fills the crop outline; longer side overflows.
        if imgSize.width <= imgSize.height {
            let w = cropSide
            let h = cropSide * imgSize.height / imgSize.width
            return CGSize(width: w, height: h)
        } else {
            let h = cropSide
            let w = cropSide * imgSize.width / imgSize.height
            return CGSize(width: w, height: h)
        }
    }

    private func clampedOffset(_ proposed: CGFloat, scale: CGFloat, base: CGFloat, cropSide: CGFloat) -> CGFloat {
        let effective = base * scale
        let slack = max(0, (effective - cropSide) / 2)
        return min(slack, max(-slack, proposed))
    }

    private func makeCroppedData(cropSide: CGFloat, base: CGSize) -> Data? {
        let normalized = upOriented(sourceImage)
        let imgSize = normalized.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }

        // base.width corresponds to imgSize.width when the image is at scale = 1.
        // pointsPerScreenPt is constant across both axes (uniform scaling).
        let pointsPerScreenPt = imgSize.width / (base.width * scale)
        let cropPointSize = cropSide * pointsPerScreenPt
        let centerX = imgSize.width / 2 - offset.width * pointsPerScreenPt
        let centerY = imgSize.height / 2 - offset.height * pointsPerScreenPt
        let originX = centerX - cropPointSize / 2
        let originY = centerY - cropPointSize / 2

        let pixelScale = normalized.scale
        let pxRect = CGRect(
            x: originX * pixelScale,
            y: originY * pixelScale,
            width: cropPointSize * pixelScale,
            height: cropPointSize * pixelScale
        ).integral

        guard let cg = normalized.cgImage,
              let cropped = cg.cropping(to: pxRect.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height)))
        else { return nil }

        let cropUI = UIImage(cgImage: cropped, scale: pixelScale, orientation: .up)
        return cropUI.jpegData(compressionQuality: 0.85)
    }

    private func upOriented(_ img: UIImage) -> UIImage {
        if img.imageOrientation == .up { return img }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = img.scale
        let renderer = UIGraphicsImageRenderer(size: img.size, format: format)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }
}
#endif
