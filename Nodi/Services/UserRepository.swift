import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum UserRepositoryError: LocalizedError {
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .usernameTaken: return "That username is already taken."
        }
    }
}

/// Firestore access layer for `users/{uid}` documents plus the
/// `usernames/{username}` reservation collection used to enforce
/// uniqueness without a Cloud Function round trip on every keystroke.
final class UserRepository {

    static let shared = UserRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var usersCollection: CollectionReference { db.collection("users") }
    private var usernamesCollection: CollectionReference { db.collection("usernames") }

    func fetchUser(uid: String) async throws -> NodiUser? {
        let snapshot = try await usersCollection.document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: NodiUser.self)
    }

    func createUser(_ user: NodiUser) async throws {
        guard let uid = user.id else { return }
        try await usersCollection.document(uid).setData(from: user, merge: false)
    }

    func updateUser(uid: String, fields: [String: Any]) async throws {
        var fields = fields
        fields["updatedAt"] = FieldValue.serverTimestamp()
        try await usersCollection.document(uid).updateData(fields)
    }

    func updateLastActive(uid: String) async throws {
        try await usersCollection.document(uid).updateData([
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
    }

    /// Deliberately bypasses `updateUser` (which also stamps `updatedAt`)
    /// — firestore.rules only lets a *non-owner* bump `profileViewCount`
    /// when nothing else on the document changes, `updatedAt` included.
    func incrementProfileView(uid: String) async {
        try? await usersCollection.document(uid).updateData([
            "profileViewCount": FieldValue.increment(Int64(1))
        ])
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let doc = try await usernamesCollection.document(username.lowercased()).getDocument()
        return !doc.exists
    }

    /// Atomically reserves a username and updates the user document. Uses a
    /// transaction so two users can never win a race for the same handle.
    func reserveUsername(_ username: String, for uid: String, previousUsername: String?) async throws {
        let normalized = username.lowercased()
        let usernameRef = usernamesCollection.document(normalized)
        let userRef = usersCollection.document(uid)

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let existing = try transaction.getDocument(usernameRef)
                if existing.exists, (existing.data()?["uid"] as? String) != uid {
                    errorPointer?.pointee = NSError(
                        domain: "Nodi",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Username taken"]
                    )
                    return nil
                }

                transaction.setData(["uid": uid, "reservedAt": FieldValue.serverTimestamp()], forDocument: usernameRef)
                transaction.updateData(["username": normalized, "updatedAt": FieldValue.serverTimestamp()], forDocument: userRef)

                if let previousUsername, !previousUsername.isEmpty, previousUsername.lowercased() != normalized {
                    let previousRef = self.usernamesCollection.document(previousUsername.lowercased())
                    transaction.deleteDocument(previousRef)
                }

                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func searchUsers(matching query: String, limit: Int = 20) async throws -> [NodiUser] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let keyword = query.lowercased()
        let snapshot = try await usersCollection
            .whereField("searchKeywords", arrayContains: keyword)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: NodiUser.self) }
    }

    /// Batched by 10 (Firestore's `in` query limit) — used by
    /// `GraphViewModel` to refresh online status for the handful of
    /// direct-connection nodes actually visible, rather than denormalizing
    /// a constantly-changing field onto every connection document.
    func fetchUsers(ids: [String]) async throws -> [NodiUser] {
        guard !ids.isEmpty else { return [] }
        var results: [NodiUser] = []
        for chunk in stride(from: 0, to: ids.count, by: 10).map({ Array(ids[$0..<min($0 + 10, ids.count)]) }) {
            let snapshot = try await usersCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            results.append(contentsOf: snapshot.documents.compactMap { try? $0.data(as: NodiUser.self) })
        }
        return results
    }

    /// A broad, recently-active pool for Discovery to filter client-side
    /// (profession/location/school/company/software/availability). Firestore
    /// can't efficiently combine that many facets server-side without a
    /// dedicated search index (Algolia/Typesense would be the real answer
    /// at scale — see README); this is the honest, working answer for a
    /// launch-scale user base.
    func fetchDiscoveryPool(limit: Int = 300) async throws -> [NodiUser] {
        let snapshot = try await usersCollection
            .order(by: "lastActiveAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: NodiUser.self) }
    }

    /// Prefix range query on `geohash` — the standard Firestore geo-query
    /// workaround. Returns an approximate bounding box, not an exact
    /// radius; callers should still sort/filter by real distance
    /// client-side using the raw lat/lng also stored on the doc.
    func fetchUsers(geohashPrefix: String, limit: Int = 100) async throws -> [NodiUser] {
        guard !geohashPrefix.isEmpty else { return [] }
        let start = geohashPrefix
        let end = geohashPrefix + "~" // '~' sorts after all geohash base32 chars
        let snapshot = try await usersCollection
            .whereField("geohash", isGreaterThanOrEqualTo: start)
            .whereField("geohash", isLessThan: end)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: NodiUser.self) }
    }

    func observeUser(uid: String, onChange: @escaping (NodiUser?) -> Void) -> ListenerRegistration {
        usersCollection.document(uid).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            onChange(try? snapshot.data(as: NodiUser.self))
        }
    }
}
