import Foundation
import UIKit

@MainActor
final class ConnectViewModel: ObservableObject {

    @Published var resolvedTargetUser: NodiUser?
    @Published var resolvedSource: ConnectionSource = .qrCode
    @Published var selectedType: ConnectionType = .friend
    @Published var isSendingRequest = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingConfirmSheet = false

    let nfcService = NFCConnectionService.shared

    func resolve(url: URL, source: ConnectionSource, currentUserId: String?) async {
        guard let uid = Self.extractUID(from: url) else {
            errorMessage = "That code isn't a valid Nodi connect link."
            return
        }
        guard uid != currentUserId else {
            errorMessage = "That's your own code!"
            return
        }

        do {
            guard let user = try await UserRepository.shared.fetchUser(uid: uid) else {
                errorMessage = "Couldn't find that Nodi profile."
                return
            }
            resolvedTargetUser = user
            resolvedSource = source
            showingConfirmSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmConnection(currentUser: NodiUser) async {
        guard let target = resolvedTargetUser else { return }
        isSendingRequest = true
        errorMessage = nil
        defer { isSendingRequest = false }

        do {
            let connection = try await ConnectionRepository.shared.request(
                from: currentUser,
                to: target,
                type: selectedType,
                source: resolvedSource
            )
            successMessage = connection.status == .accepted
                ? "Connected with \(target.displayName)!"
                : "Request sent to \(target.displayName)."
            showingConfirmSheet = false
            resolvedTargetUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func extractUID(from url: URL) -> String? {
        guard let link = NodiDeepLink(url: url), case .connect(let token) = link else { return nil }
        return token
    }
}
