import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isDeletingAccount = false
    @Published var errorMessage: String?

    func deleteAccount(session: SessionStore) async -> Bool {
        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }
        do {
            try await AuthService.shared.deleteAccount()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
