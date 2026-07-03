import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum ConnectionRepositoryError: LocalizedError {
    case alreadyConnected
    case cannotConnectToSelf

    var errorDescription: String? {
        switch self {
        case .alreadyConnected: return "You're already connected (or have a pending request) with this person."
        case .cannotConnectToSelf: return "You can't connect with yourself."
        }
    }
}

/// Connection counts on `NodiUser` (`connectionCount`) are intentionally
/// locked out of client writes by firestore.rules — they're incremented by
/// the `onConnectionAccepted` Cloud Function so the number can never drift
/// from reality (e.g. a client crashing mid-write, or two accepts racing).
final class ConnectionRepository {

    static let shared = ConnectionRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var connectionsCollection: CollectionReference { db.collection("connections") }

    func existingConnection(between uidA: String, _ uidB: String) async throws -> Connection? {
        let docId = Connection.documentId(for: uidA, uidB)
        let snapshot = try await connectionsCollection.document(docId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: Connection.self)
    }

    @discardableResult
    func request(
        from currentUser: NodiUser,
        to targetUser: NodiUser,
        type: ConnectionType,
        source: ConnectionSource
    ) async throws -> Connection {
        guard let currentId = currentUser.id, let targetId = targetUser.id else {
            throw ConnectionRepositoryError.cannotConnectToSelf
        }
        guard currentId != targetId else { throw ConnectionRepositoryError.cannotConnectToSelf }

        if let existing = try await existingConnection(between: currentId, targetId), existing.status != .declined {
            throw ConnectionRepositoryError.alreadyConnected
        }

        // NFC is physical-proximity proof of consent from both sides — it
        // connects immediately. Everything else (QR, link, search) creates
        // a request the other person must accept, same as a follow request
        // would need to be on a private account.
        let status: ConnectionStatus = source == .nfcTag ? .accepted : .pending

        let connectionId = Connection.documentId(for: currentId, targetId)
        let connection = Connection(
            id: connectionId,
            participantIds: [currentId, targetId].sorted(),
            participants: [
                currentId: ConnectionParticipantSummary(
                    displayName: currentUser.displayName,
                    username: currentUser.username,
                    photoURL: currentUser.profilePhotoURL,
                    profession: currentUser.profession
                ),
                targetId: ConnectionParticipantSummary(
                    displayName: targetUser.displayName,
                    username: targetUser.username,
                    photoURL: targetUser.profilePhotoURL,
                    profession: targetUser.profession
                )
            ],
            requestedBy: currentId,
            type: type,
            status: status,
            source: source,
            createdAt: Date(),
            respondedAt: status == .accepted ? Date() : nil
        )

        try await connectionsCollection.document(connectionId).setData(from: connection, merge: false)
        return connection
    }

    func respond(to connectionId: String, accept: Bool) async throws {
        try await connectionsCollection.document(connectionId).updateData([
            "status": accept ? ConnectionStatus.accepted.rawValue : ConnectionStatus.declined.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchConnections(for uid: String) async throws -> [Connection] {
        let snapshot = try await connectionsCollection
            .whereField("participantIds", arrayContains: uid)
            .whereField("status", isEqualTo: ConnectionStatus.accepted.rawValue)
            .order(by: "respondedAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Connection.self) }
    }

    func fetchPendingRequests(for uid: String) async throws -> [Connection] {
        let snapshot = try await connectionsCollection
            .whereField("participantIds", arrayContains: uid)
            .whereField("status", isEqualTo: ConnectionStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: Connection.self) }
            .filter { $0.requestedBy != uid } // only requests *incoming* to this user
    }

    func observePendingRequestCount(for uid: String, onChange: @escaping (Int) -> Void) -> ListenerRegistration {
        connectionsCollection
            .whereField("participantIds", arrayContains: uid)
            .whereField("status", isEqualTo: ConnectionStatus.pending.rawValue)
            .addSnapshotListener { snapshot, _ in
                let incoming = snapshot?.documents
                    .compactMap { try? $0.data(as: Connection.self) }
                    .filter { $0.requestedBy != uid } ?? []
                onChange(incoming.count)
            }
    }
}
