import Foundation
import FirebaseAuth
import Combine

enum AuthState: Equatable {
    case loading
    case signedOut
    case needsOnboarding
    case signedIn
}

/// The single source of truth for "who is signed in and what's their
/// profile." Every top-level view branches off `authState`.
@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentUser: NodiUser?
    @Published var authErrorMessage: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthChanges()
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    private func listenToAuthChanges() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                await self.handleAuthChange(firebaseUser: firebaseUser)
            }
        }
    }

    private func handleAuthChange(firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            authState = .signedOut
            currentUser = nil
            return
        }

        do {
            if let user = try await UserRepository.shared.fetchUser(uid: firebaseUser.uid) {
                currentUser = user
                authState = user.onboardingComplete ? .signedIn : .needsOnboarding
                try? await UserRepository.shared.updateLastActive(uid: firebaseUser.uid)
            } else {
                let providers = firebaseUser.providerData.compactMap { AuthProvider(providerID: $0.providerID) }
                let draft = NodiUser.draft(
                    uid: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? "",
                    providers: providers.isEmpty ? [.email] : providers
                )
                try await UserRepository.shared.createUser(draft)
                currentUser = draft
                authState = .needsOnboarding
            }
        } catch {
            authErrorMessage = error.localizedDescription
            authState = .signedOut
        }
    }

    func refreshCurrentUser() async {
        guard let uid = currentUser?.id else { return }
        currentUser = try? await UserRepository.shared.fetchUser(uid: uid)
    }

    func completeOnboarding() {
        guard var user = currentUser else { return }
        user.onboardingComplete = true
        currentUser = user
        authState = .signedIn
    }

    func signOut() {
        do {
            try AuthService.shared.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }
}

private extension AuthProvider {
    init?(providerID: String) {
        switch providerID {
        case "apple.com": self = .apple
        case "google.com": self = .google
        case "password": self = .email
        default: return nil
        }
    }
}
