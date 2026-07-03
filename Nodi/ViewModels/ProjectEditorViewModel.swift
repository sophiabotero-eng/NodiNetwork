import Foundation
import UIKit

@MainActor
final class ProjectEditorViewModel: ObservableObject {

    private(set) var projectId: String?
    private let ownerId: String
    private let owner: NodiUser
    private let existingCreatedAt: Date
    private let existingViewCount: Int

    @Published var title: String
    @Published var projectDescription: String
    @Published var tags: [String]
    @Published var tagInput = ""
    @Published var softwareUsed: [String]
    @Published var softwareInput = ""
    @Published var year: Int
    @Published var collaborators: [CollaboratorRef]
    @Published var collaboratorSearchQuery = ""
    @Published var collaboratorResults: [NodiUser] = []

    @Published var mediaItems: [ProjectMediaItem]
    @Published var coverImageURL: String?

    @Published var isUploadingMedia = false
    @Published var uploadProgress: Double = 0
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var didDelete = false

    struct CollaboratorRef: Identifiable, Equatable {
        let id: String
        let name: String
    }

    var isEditingExisting: Bool { projectId != nil }

    var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !mediaItems.isEmpty
    }

    init(owner: NodiUser, existing: PortfolioProject? = nil) {
        self.owner = owner
        self.ownerId = owner.id ?? ""
        self.projectId = existing?.id
        self.title = existing?.title ?? ""
        self.projectDescription = existing?.projectDescription ?? ""
        self.tags = existing?.tags ?? []
        self.softwareUsed = existing?.softwareUsed ?? []
        self.year = existing?.year ?? Calendar.current.component(.year, from: Date())
        self.collaborators = zip(existing?.collaboratorIds ?? [], existing?.collaboratorNames ?? []).map {
            CollaboratorRef(id: $0, name: $1)
        }
        self.mediaItems = existing?.mediaItems ?? []
        self.coverImageURL = existing?.coverImageURL
        self.existingCreatedAt = existing?.createdAt ?? Date()
        self.existingViewCount = existing?.viewCount ?? 0
    }

    // MARK: Tags / Software

    func addTag(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    func removeTag(_ value: String) { tags.removeAll { $0 == value } }

    func addSoftware(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !softwareUsed.contains(trimmed) else { return }
        softwareUsed.append(trimmed)
        softwareInput = ""
    }

    func removeSoftware(_ value: String) { softwareUsed.removeAll { $0 == value } }

    // MARK: Collaborators

    func searchCollaborators() async {
        guard !collaboratorSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            collaboratorResults = []
            return
        }
        collaboratorResults = (try? await UserRepository.shared.searchUsers(matching: collaboratorSearchQuery)) ?? []
    }

    func addCollaborator(_ user: NodiUser) {
        guard let id = user.id, !collaborators.contains(where: { $0.id == id }) else { return }
        collaborators.append(CollaboratorRef(id: id, name: user.displayName))
        collaboratorSearchQuery = ""
        collaboratorResults = []
    }

    func removeCollaborator(_ ref: CollaboratorRef) {
        collaborators.removeAll { $0.id == ref.id }
    }

    // MARK: Media

    func addImage(_ image: UIImage) async {
        isUploadingMedia = true
        defer { isUploadingMedia = false }
        do {
            let url = try await StorageService.shared.uploadImage(
                image,
                kind: .projectImage,
                ownerId: ownerId,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.uploadProgress = progress }
                }
            )
            let item = ProjectMediaItem(kind: .image, url: url.absoluteString, thumbnailURL: url.absoluteString, order: mediaItems.count)
            mediaItems.append(item)
            if coverImageURL == nil { coverImageURL = url.absoluteString }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addVideo(fileURL: URL) async {
        isUploadingMedia = true
        defer { isUploadingMedia = false }
        do {
            let videoData = try Data(contentsOf: fileURL)
            let videoURL = try await StorageService.shared.uploadData(
                videoData,
                kind: .projectVideo,
                ownerId: ownerId,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.uploadProgress = progress }
                }
            )

            var thumbnailURLString: String?
            if let thumbnail = await MediaThumbnailGenerator.videoThumbnail(url: fileURL) {
                let thumbURL = try await StorageService.shared.uploadImage(thumbnail, kind: .projectImage, ownerId: ownerId)
                thumbnailURLString = thumbURL.absoluteString
            }

            let item = ProjectMediaItem(kind: .video, url: videoURL.absoluteString, thumbnailURL: thumbnailURLString, order: mediaItems.count)
            mediaItems.append(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPDF(fileURL: URL) async {
        isUploadingMedia = true
        defer { isUploadingMedia = false }
        do {
            let accessed = fileURL.startAccessingSecurityScopedResource()
            defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }

            let pdfData = try Data(contentsOf: fileURL)
            let pdfURL = try await StorageService.shared.uploadData(
                pdfData,
                kind: .projectPDF,
                ownerId: ownerId,
                onProgress: { [weak self] progress in
                    Task { @MainActor in self?.uploadProgress = progress }
                }
            )

            var thumbnailURLString: String?
            if let thumbnail = MediaThumbnailGenerator.pdfThumbnail(url: fileURL) {
                let thumbURL = try await StorageService.shared.uploadImage(thumbnail, kind: .projectImage, ownerId: ownerId)
                thumbnailURLString = thumbURL.absoluteString
            }

            let item = ProjectMediaItem(kind: .pdf, url: pdfURL.absoluteString, thumbnailURL: thumbnailURLString, order: mediaItems.count)
            mediaItems.append(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMedia(_ item: ProjectMediaItem) {
        mediaItems.removeAll { $0.id == item.id }
        if coverImageURL == item.url {
            coverImageURL = mediaItems.first(where: { $0.kind == .image })?.url
        }
        reindexMedia()
    }

    func moveMedia(from source: IndexSet, to destination: Int) {
        mediaItems.move(fromOffsets: source, toOffset: destination)
        reindexMedia()
    }

    func setCover(_ item: ProjectMediaItem) {
        coverImageURL = item.thumbnailURL ?? item.url
    }

    private func reindexMedia() {
        for index in mediaItems.indices {
            mediaItems[index].order = index
        }
    }

    // MARK: Save

    func saveDraft(session: SessionStore) async {
        await save(status: .draft, session: session)
    }

    func publish(session: SessionStore) async {
        guard canPublish else {
            errorMessage = "Add a title and at least one piece of media before publishing."
            return
        }
        await save(status: .published, session: session)
    }

    private func save(status: ProjectStatus, session: SessionStore) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var project = PortfolioProject(
            id: projectId,
            ownerId: ownerId,
            ownerUsername: owner.username,
            ownerDisplayName: owner.displayName,
            ownerPhotoURL: owner.profilePhotoURL,
            title: title,
            projectDescription: projectDescription,
            tags: tags,
            softwareUsed: softwareUsed,
            year: year,
            collaboratorIds: collaborators.map(\.id),
            collaboratorNames: collaborators.map(\.name),
            coverImageURL: coverImageURL,
            mediaItems: mediaItems,
            status: status,
            viewCount: existingViewCount,
            searchKeywords: [],
            createdAt: existingCreatedAt,
            updatedAt: Date()
        )

        do {
            let id = try await ProjectRepository.shared.save(project)
            projectId = id
            project.id = id
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete() async {
        guard let projectId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProjectRepository.shared.delete(projectId: projectId)
            didDelete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
