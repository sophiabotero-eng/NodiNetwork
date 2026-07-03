import Foundation
import FirebaseFirestoreSwift

/// `users/{uid}/recommendations/{candidateId}` — written by the
/// `recomputeRecommendations` Cloud Function (see functions/src/
/// recommendations.ts for the actual scoring heuristic). Read-only from
/// the client.
struct ConnectionRecommendation: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var candidateId: String
    var displayName: String
    var username: String
    var profilePhotoURL: String?
    var profession: String
    var score: Double
    var reasons: [String]
    var computedAt: Date
}
