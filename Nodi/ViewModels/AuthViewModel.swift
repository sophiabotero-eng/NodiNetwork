import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mode: Mode = .signIn

    /// Raw nonce for the in-flight Sign in with Apple request. Generated
    /// fresh each time the button configures a new request, consumed once
    /// the system sheet completes.
    private var pendingAppleNonce: String?

    enum Mode {
        case signIn
        case signUp
    }

    var isFormValid: Bool {
        guard email.contains("@"), email.contains(".") else { return false }
        guard password.count >= 8 else { return false }
        if mode == .signUp { return password == confirmPassword }
        return true
    }

    /// Called from the button's request-configuration closure. Returns the
    /// hashed nonce to set on the `ASAuthorizationAppleIDRequest`.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AuthService.shared.makeAppleNonce()
        pendingAppleNonce = nonce.raw
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce.hashed
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        guard let rawNonce = pendingAppleNonce else { return }
        pendingAppleNonce = nil

        switch result {
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        case .success(let authorization):
            await run { try await AuthService.shared.signIn(withApple: authorization, rawNonce: rawNonce) }
        }
    }

    func signInWithGoogle() async {
        await run { try await AuthService.shared.signInWithGoogle() }
    }

    func submitEmailForm() async {
        guard isFormValid else {
            errorMessage = mode == .signUp && password != confirmPassword
                ? "Passwords don't match."
                : "Enter a valid email and an 8+ character password."
            return
        }
        await run {
            switch self.mode {
            case .signIn:
                return try await AuthService.shared.signIn(email: self.email, password: self.password)
            case .signUp:
                return try await AuthService.shared.signUp(email: self.email, password: self.password)
            }
        }
    }

    func sendPasswordReset() async {
        guard email.contains("@") else {
            errorMessage = "Enter your email above first."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.sendPasswordReset(email: email)
            errorMessage = "Password reset email sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func run(_ operation: @escaping () async throws -> Any) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await operation()
            // SessionStore's auth-state listener picks up the resulting
            // FirebaseAuth.User change and drives navigation from there.
        } catch AuthServiceError.cancelled {
            // User backed out of the system sheet; not an error worth showing.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
