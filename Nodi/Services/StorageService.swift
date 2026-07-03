import Foundation
import UIKit
import FirebaseStorage

enum MediaKind: String {
    case profilePhoto
    case coverImage
    case projectImage
    case projectVideo
    case projectPDF
    case voiceMessage

    var storageFolder: String {
        switch self {
        case .profilePhoto: return "profile_photos"
        case .coverImage: return "cover_images"
        case .projectImage: return "project_media/images"
        case .projectVideo: return "project_media/videos"
        case .projectPDF: return "project_media/documents"
        case .voiceMessage: return "voice_messages"
        }
    }

    var contentType: String {
        switch self {
        case .profilePhoto, .coverImage, .projectImage: return "image/jpeg"
        case .projectVideo: return "video/mp4"
        case .projectPDF: return "application/pdf"
        case .voiceMessage: return "audio/m4a"
        }
    }

    var fileExtension: String {
        switch self {
        case .profilePhoto, .coverImage, .projectImage: return "jpg"
        case .projectVideo: return "mp4"
        case .projectPDF: return "pdf"
        case .voiceMessage: return "m4a"
        }
    }
}

struct UploadProgress {
    let fractionCompleted: Double
}

/// Thin async wrapper around Firebase Storage uploads with JPEG
/// re-compression for images so we never ship a full-resolution camera
/// photo straight into a portfolio grid.
final class StorageService {

    static let shared = StorageService()

    private let storage = Storage.storage()
    private init() {}

    func uploadImage(
        _ image: UIImage,
        kind: MediaKind,
        ownerId: String,
        compressionQuality: CGFloat = 0.82,
        maxDimension: CGFloat = 2048,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let resized = image.resized(maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            throw StorageServiceError.encodingFailed
        }
        return try await uploadData(data, kind: kind, ownerId: ownerId, onProgress: onProgress)
    }

    func uploadData(
        _ data: Data,
        kind: MediaKind,
        ownerId: String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let path = "\(kind.storageFolder)/\(ownerId)/\(UUID().uuidString).\(kind.fileExtension)"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = kind.contentType

        return try await withCheckedThrowingContinuation { continuation in
            let task = ref.putData(data, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                ref.downloadURL { url, error in
                    if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: error ?? StorageServiceError.missingDownloadURL)
                    }
                }
            }
            task.observe(.progress) { snapshot in
                guard let progress = snapshot.progress else { return }
                let fraction = Double(progress.completedUnitCount) / Double(max(progress.totalUnitCount, 1))
                onProgress?(fraction)
            }
        }
    }

    func delete(url: URL) async throws {
        try await storage.reference(forURL: url.absoluteString).delete()
    }
}

enum StorageServiceError: LocalizedError {
    case encodingFailed
    case missingDownloadURL

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Couldn't prepare that image for upload."
        case .missingDownloadURL: return "Upload finished but no download URL was returned."
        }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
