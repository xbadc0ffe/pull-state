import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Wraps a button label with an action sheet offering Photos + (when available)
/// Camera. After the user picks or captures a photo we show `PSPhotoCropSheet`
/// so the saved JPEG is always cropped to a square — keeping the thumbnail
/// slots used elsewhere in the app uniform.
struct PSPhotoSourceMenu<Label: View>: View {
    @Binding var data: Data?
    @ViewBuilder var label: () -> Label

    @State private var showSheet = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showPhotos = false
    @State private var showCamera = false
    #if canImport(UIKit)
    @State private var pendingCrop: PendingCropImage? = nil
    #endif

    private var cameraAvailable: Bool {
        #if canImport(UIKit)
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        false
        #endif
    }

    var body: some View {
        Button {
            if cameraAvailable {
                showSheet = true
            } else {
                showPhotos = true
            }
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .confirmationDialog("Add Photo", isPresented: $showSheet, titleVisibility: .hidden) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Photos") { showPhotos = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotos, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let imgData = try? await newItem.loadTransferable(type: Data.self) {
                    #if canImport(UIKit)
                    if let img = UIImage(data: imgData) {
                        await MainActor.run {
                            pendingCrop = PendingCropImage(image: img)
                            pickerItem = nil
                        }
                        return
                    }
                    #endif
                    await MainActor.run {
                        data = imgData
                        pickerItem = nil
                    }
                }
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker { captured in
                if let captured {
                    pendingCrop = PendingCropImage(image: captured)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $pendingCrop) { wrap in
            PSPhotoCropSheet(
                sourceImage: wrap.image,
                onCommit: { croppedData in
                    data = croppedData
                    pendingCrop = nil
                },
                onCancel: { pendingCrop = nil }
            )
        }
        #endif
    }
}

#if canImport(UIKit)
/// Identifiable wrapper so the crop sheet can be presented via
/// `.fullScreenCover(item:)`, which dismisses cleanly when set back to nil.
private struct PendingCropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.allowsEditing = false
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            parent.dismiss()
            // Defer the callback so the camera fullScreenCover finishes
            // dismissing before the crop sheet is presented — otherwise
            // SwiftUI may swallow the new presentation.
            DispatchQueue.main.async {
                self.parent.onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
            DispatchQueue.main.async {
                self.parent.onCapture(nil)
            }
        }
    }
}
#endif
