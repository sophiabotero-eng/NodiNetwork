import SwiftUI
import PhotosUI

/// Wraps `PhotosPicker` and does the `Data -> UIImage` decode off the main
/// actor, handing the view model a ready `UIImage` instead of raw
/// `PhotosPickerItem` plumbing scattered across every screen that needs a
/// photo.
struct NodiPhotoPickerButton<Label: View>: View {
    @Binding var selectedImage: UIImage?
    var matching: PHPickerFilter = .images
    @ViewBuilder var label: () -> Label

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: matching) {
            label()
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                selectedImage = UIImage(data: data)
            }
        }
    }
}
