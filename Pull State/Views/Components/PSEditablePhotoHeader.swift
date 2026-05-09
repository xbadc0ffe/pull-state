import SwiftUI

/// Square photo header with a pencil overlay that opens the standard
/// `PSPhotoSourceMenu` action sheet (Take Photo / Choose from Photos / Crop /
/// Remove). Used as the visual header on add/edit forms — replaces the
/// standalone `PhotoEditCard` row that previously appeared at the bottom of
/// each form.
struct PSEditablePhotoHeader: View {
    @Binding var data: Data?
    var label: String = "PHOTO"
    var radius: CGFloat = 14

    @Environment(\.psPalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PSPhotoThumb(data: data, label: label, radius: radius)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 8) {
                if data != nil {
                    Button {
                        data = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.inkSoft)
                            .frame(width: 36, height: 36)
                            .background(palette.surface, in: Circle())
                            .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                            .psShadow(strong: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo")
                }
                PSPhotoSourceMenu(data: $data) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, height: 44)
                        .background(palette.surface, in: Circle())
                        .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                        .psShadow(strong: false)
                }
                .accessibilityLabel(data == nil ? "Add photo" : "Change photo")
            }
            .padding(12)
        }
    }
}
