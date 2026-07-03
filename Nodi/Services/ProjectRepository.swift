import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class ProjectRepository {

    static let shared = ProjectRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var projectsCollection: CollectionReference { db.collection("projects") }

    @discardableResult
    func save(_ project: PortfolioProject) async throws -> String {
        var project = project
        project.updatedAt = Date()
        project.searchKeywords = PortfolioProject.buildSearchKeywords(
            title: project.title,
            tags: project.tags,
            software: project.softwareUsed
        )

        if let id = project.id {
            try await projectsCollection.document(id).setData(from: project, merge: false)
            return id
        } else {
            let ref = try await projectsCollection.addDocument(from: project)
            return ref.documentID
        }
    }

    func delete(projectId: String) async throws {
        try await projectsCollection.document(projectId).delete()
    }

    func fetchProject(id: String) async throws -> PortfolioProject? {
        let snapshot = try await projectsCollection.document(id).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: PortfolioProject.self)
    }

    /// All of a user's projects, both draft and published — used on your
    /// own profile where you can see and manage everything you've made.
    func fetchAllProjects(ownerId: String) async throws -> [PortfolioProject] {
        let snapshot = try await projectsCollection
            .whereField("ownerId", isEqualTo: ownerId)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PortfolioProject.self) }
    }

    /// Only published projects — used on other people's profiles and
    /// anywhere projects surface publicly (search, discovery, graph).
    func fetchPublishedProjects(ownerId: String) async throws -> [PortfolioProject] {
        let snapshot = try await projectsCollection
            .whereField("ownerId", isEqualTo: ownerId)
            .whereField("status", isEqualTo: ProjectStatus.published.rawValue)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PortfolioProject.self) }
    }

    func searchProjects(matching query: String, limit: Int = 30) async throws -> [PortfolioProject] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let snapshot = try await projectsCollection
            .whereField("status", isEqualTo: ProjectStatus.published.rawValue)
            .whereField("searchKeywords", arrayContains: query.lowercased())
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PortfolioProject.self) }
    }

    func incrementViewCount(projectId: String) async {
        try? await projectsCollection.document(projectId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
    }
}
