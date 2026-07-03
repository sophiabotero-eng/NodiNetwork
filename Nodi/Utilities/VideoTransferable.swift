import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// `PhotosPickerItem.loadTransferable(type: Data.self)` isn't a great fit
/// for video — it loads the whole thing into memory. This copies the
/// picked video to a temp file instead, which is what we actually want
/// before handing it to `StorageService`.
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}
