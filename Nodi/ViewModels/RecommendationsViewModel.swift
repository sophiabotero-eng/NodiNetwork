import Foundation
import FirebaseFirestore

@MainActor
final class RecommendationsViewModel: ObservableObject {
    @Published var recommendations: [ConnectionRecommendation] = []
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    func startObserving(uid: String) {
        listener = RecommendationService.shared.observeRecommendations(for: uid) { [weak self] recommendations in
            self?.recommendations = recommendations
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await RecommendationService.shared.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismiss(uid: String, recommendation: ConnectionRecommendation) async {
        await RecommendationService.shared.dismiss(uid: uid, candidateId: recommendation.candidateId)
    }

    deinit {
        listener?.remove()
    }
}
