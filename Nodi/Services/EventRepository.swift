import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class EventRepository {

    static let shared = EventRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var eventsCollection: CollectionReference { db.collection("events") }

    @discardableResult
    func create(_ event: NodiEvent) async throws -> String {
        let ref = try await eventsCollection.addDocument(from: event)
        return ref.documentID
    }

    func fetchUpcoming(limit: Int = 50) async throws -> [NodiEvent] {
        let snapshot = try await eventsCollection
            .whereField("startsAt", isGreaterThanOrEqualTo: Date())
            .order(by: "startsAt", descending: false)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: NodiEvent.self) }
    }

    func fetchNearby(geohashPrefix: String, limit: Int = 50) async throws -> [NodiEvent] {
        guard !geohashPrefix.isEmpty else { return [] }
        let snapshot = try await eventsCollection
            .whereField("geohash", isGreaterThanOrEqualTo: geohashPrefix)
            .whereField("geohash", isLessThan: geohashPrefix + "~")
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: NodiEvent.self) }
            .filter { $0.isUpcoming }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func toggleAttendance(eventId: String, uid: String, attending: Bool) async throws {
        let field: Any = attending ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
        try await eventsCollection.document(eventId).updateData(["attendeeIds": field])
    }

    func delete(eventId: String) async throws {
        try await eventsCollection.document(eventId).delete()
    }
}
