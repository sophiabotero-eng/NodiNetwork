import Foundation
import FirebaseFirestore

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user: NodiUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    let userId: String
    let isOwnProfile: Bool

    init(userId: String, isOwnProfile: Bool) {
        self.userId = userId
        self.isOwnProfile = isOwnProfile
    }

    deinit {
        listener?.remove()
    }

    func startObserving() {
        isLoading = true
        listener = UserRepository.shared.observeUser(uid: userId) { [weak self] user in
            self?.user = user
            self?.isLoading = false
        }
    }
}
