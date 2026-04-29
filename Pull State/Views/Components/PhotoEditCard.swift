import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A reusable photo card row with thumbnail + Add/Change + remove (when set).
struct PhotoEditCard: View {
    @Binding var data: Data?
    var hint: String? = nil
    @Environment(\.psPalette) private var palette

    var body: some View {
        PSCard {
            HStack(spacing: 12) {
                Group {
                    #if canImport(UIKit)
                    if let data, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        PSPlaceholder(label: "PHOTO", radius: 10)
                    }
                    #else
                    PSPlaceholder(label: "PHOTO", radius: 10)
                    #endif
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(data == nil ? "Add a photo" : "Photo attached")
                        .font(PSFont.body(13, weight: .semibold))
                        .foregroundStyle(palette.ink)
                    if let hint {
                        Text(hint)
                            .font(PSFont.body(11))
                            .foregroundStyle(palette.inkSoft)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    if data != nil {
                        Button {
                            data = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.inkSoft)
                                .frame(width: 28, height: 28)
                                .background(palette.surface, in: Circle())
                                .overlay(Circle().strokeBorder(palette.line, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove photo")
                    }
                    PSPhotoSourceMenu(data: $data) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.system(size: 12))
                            Text(data == nil ? "Add" : "Change")
                                .font(PSFont.body(12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(data == nil ? palette.ink : Color.white)
                        .background(data == nil ? palette.surface : palette.accent, in: Capsule())
                        .overlay(Capsule().strokeBorder(palette.line, lineWidth: 0.5))
                    }
                }
            }
            .padding(14)
        }
    }
}
