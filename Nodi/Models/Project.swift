import Foundation
import FirebaseFirestoreSwift

enum ProjectStatus: String, Codable, CaseIterable {
    case draft
    case published
}

enum ProjectMediaKind: String, Codable {
    case image
    case video
    case pdf
}

struct ProjectMediaItem: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var kind: ProjectMediaKind
    var url: String
    /// For video/PDF, a generated still frame / first-page thumbnail so the
    /// grid and viewer don't need to load the full asset just to render a
    /// preview tile.
    var thumbnailURL: String?
    var order: Int

    init(id: String = UUID().uuidString, kind: ProjectMediaKind, url: String, thumbnailURL: String? = nil, order: Int) {
        self.id = id
        self.kind = kind
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.order = order
    }
}

/// Top-level `projects/{id}` collection (rather than a subcollection of
/// `users`) so Discovery (Phase 3) and the graph (Phase 4) can query across
/// everyone's published work — e.g. "projects tagged 'branding' near me" —
/// without a collection-group query.
struct PortfolioProject: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?

    var ownerId: String
    var ownerUsername: String
    var ownerDisplayName: String
    var ownerPhotoURL: String?

    var title: String
    var projectDescription: String
    var tags: [String]
    var softwareUsed: [String]
    var year: Int
    var collaboratorIds: [String]
    var collaboratorNames: [String]

    var coverImageURL: String?
    var mediaItems: [ProjectMediaItem]

    var status: ProjectStatus
    var viewCount: Int

    var searchKeywords: [String]

    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case ownerUsername
        case ownerDisplayName
        case ownerPhotoURL
        case title
        case projectDescription
        case tags
        case softwareUsed
        case year
        case collaboratorIds
        case collaboratorNames
        case coverImageURL
        case mediaItems
        case status
        case viewCount
        case searchKeywords
        case createdAt
        case updatedAt
    }

    static func draft(owner: NodiUser) -> PortfolioProject {
        let now = Date()
        return PortfolioProject(
            id: nil,
            ownerId: owner.id ?? "",
            ownerUsername: owner.username,
            ownerDisplayName: owner.displayName,
            ownerPhotoURL: owner.profilePhotoURL,
            title: "",
            projectDescription: "",
            tags: [],
            softwareUsed: [],
            year: Calendar.current.component(.year, from: now),
            collaboratorIds: [],
            collaboratorNames: [],
            coverImageURL: nil,
            mediaItems: [],
            status: .draft,
            viewCount: 0,
            searchKeywords: [],
            createdAt: now,
            updatedAt: now
        )
    }

    static func buildSearchKeywords(title: String, tags: [String], software: [String]) -> [String] {
        let raw = ([title] + tags + software)
            .joined(separator: " ")
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        return Array(Set(raw)).filter { !$0.isEmpty }
    }
}
