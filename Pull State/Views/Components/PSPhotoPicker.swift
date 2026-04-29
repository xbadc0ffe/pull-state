import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Wraps a button label with an action sheet offering Photos + (when available) Camera.
struct PSPhotoSourceMenu<Label: View>: View {
    @Binding var data: Data?
    @ViewBuilder var label: () -> Label

    @State private var showSheet = false
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showPhotos = false
    @State private var showCamera = false

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
                    await MainActor.run { data = imgData }
                }
            }
        }
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(data: $data)
                .ignoresSafeArea()
        }
        #endif
    }
}

#if canImport(UIKit)
private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var data: Data?
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
            if let image = info[.originalImage] as? UIImage,
               let jpeg = image.jpegData(compressionQuality: 0.85) {
                parent.data = jpeg
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
