import Foundation
import FirebaseFirestoreSwift

/// Top-level `events/{id}` collection. Nearby discovery reuses the same
/// geohash-prefix-range pattern as Discovery's nearby creatives (Phase 3)
/// — see Geohash.swift.
struct NodiEvent: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var title: String
    var eventDescription: String
    var coverImageURL: String?

    var hostId: String
    var hostDisplayName: String
    var hostPhotoURL: String?

    var location: String
    var geohash: String?
    var latitude: Double?
    var longitude: Double?

    var startsAt: Date
    var endsAt: Date?

    var attendeeIds: [String]
    var createdAt: Date

    var isUpcoming: Bool { startsAt >= Date() }
}
