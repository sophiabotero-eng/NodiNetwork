import Foundation
import FirebaseFirestore

final class FollowRepository {

    static let shared = FollowRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var followsCollection: CollectionReference { db.collection("follows") }

    func follow(followerId: String, followingId: String) async throws {
        guard followerId != followingId else { return }
        let docId = Follow.documentId(follower: followerId, following: followingId)
        let follow = Follow(id: docId, followerId: followerId, followingId: followingId, createdAt: Date())
        try await followsCollection.document(docId).setData(from: follow, merge: false)
    }

    func unfollow(followerId: String, followingId: String) async throws {
        let docId = Follow.documentId(follower: followerId, following: followingId)
        try await followsCollection.document(docId).delete()
    }

    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let docId = Follow.documentId(follower: followerId, following: followingId)
        let snapshot = try await followsCollection.document(docId).getDocument()
        return snapshot.exists
    }

    func fetchFollowing(uid: String) async throws -> [String] {
        let snapshot = try await followsCollection.whereField("followerId", isEqualTo: uid).getDocuments()
        return snapshot.documents.compactMap { $0["followingId"] as? String }
    }

    func fetchFollowers(uid: String) async throws -> [String] {
        let snapshot = try await followsCollection.whereField("followingId", isEqualTo: uid).getDocuments()
        return snapshot.documents.compactMap { $0["followerId"] as? String }
    }
}
