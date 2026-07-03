import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import UIKit

enum AuthServiceError: LocalizedError {
    case missingPresentingViewController
    case invalidAppleCredential
    case invalidGoogleCredential
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingPresentingViewController:
            return "Couldn't find a window to present sign-in from."
        case .invalidAppleCredential:
            return "Apple didn't return a valid identity token. Please try again."
        case .invalidGoogleCredential:
            return "Google didn't return a valid identity token. Please try again."
        case .cancelled:
            return "Sign-in was cancelled."
        }
    }
}

/// Wraps Firebase Auth plus the two federated-identity SDKs (Sign in with
/// Apple, Google Sign-In) behind a single async/await surface.
@MainActor
final class AuthService: NSObject {

    static let shared = AuthService()

    private override init() { super.init() }

    // MARK: Email / Password

    func signUp(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: Sign in with Apple
    //
    // SwiftUI's `SignInWithAppleButton` owns presentation of the system
    // sheet itself, so instead of driving our own `ASAuthorizationController`
    // (which would fight the button for a delegate), the view generates a
    // nonce via `makeAppleNonce()`, hands the sha256 of it to the button's
    // request, and on completion passes the resulting `ASAuthorization`
    // plus the raw nonce back here to exchange for a Firebase credential.

    func makeAppleNonce() -> (raw: String, hashed: String) {
        let raw = Self.randomNonceString()
        return (raw, Self.sha256(raw))
    }

    func signIn(withApple authorization: ASAuthorization, rawNonce: String) async throws -> AuthDataResult {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            throw AuthServiceError.invalidAppleCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )

        return try await Auth.auth().signIn(with: credential)
    }

    // MARK: Google Sign-In

    func signInWithGoogle() async throws -> AuthDataResult {
        guard let presenting = Self.topViewController() else {
            throw AuthServiceError.missingPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.invalidGoogleCredential
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        return try await Auth.auth().signIn(with: credential)
    }

    // MARK: Session

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }

    var currentUID: String? { Auth.auth().currentUser?.uid }

    // MARK: Helpers

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

