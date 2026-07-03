import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions

final class RecommendationService {
    static let shared = RecommendationService()

    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private init() {}

    func observeRecommendations(for uid: String, onChange: @escaping ([ConnectionRecommendation]) -> Void) -> ListenerRegistration {
        db.collection("users").document(uid).collection("recommendations")
            .order(by: "score", descending: true)
            .addSnapshotListener { snapshot, _ in
                let recommendations = snapshot?.documents.compactMap { try? $0.data(as: ConnectionRecommendation.self) } ?? []
                onChange(recommendations)
            }
    }

    func refresh() async throws {
        _ = try await functions.httpsCallable("recomputeRecommendations").call()
    }

    func dismiss(uid: String, candidateId: String) async {
        try? await db.collection("users").document(uid).collection("recommendations").document(candidateId).delete()
    }
}
