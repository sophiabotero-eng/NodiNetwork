import Foundation
import FirebaseFirestore

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user: NodiUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isFollowing = false
    @Published private(set) var isUpdatingFollow = false

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
        if !isOwnProfile {
            Task { await UserRepository.shared.incrementProfileView(uid: userId) }
        }
    }

    func loadFollowState(currentUserId: String?) async {
        guard !isOwnProfile, let currentUserId else { return }
        isFollowing = (try? await FollowRepository.shared.isFollowing(followerId: currentUserId, followingId: userId)) ?? false
    }

    func toggleFollow(currentUserId: String?) async {
        guard !isOwnProfile, let currentUserId else { return }
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }

        do {
            if isFollowing {
                try await FollowRepository.shared.unfollow(followerId: currentUserId, followingId: userId)
                isFollowing = false
            } else {
                try await FollowRepository.shared.follow(followerId: currentUserId, followingId: userId)
                isFollowing = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
