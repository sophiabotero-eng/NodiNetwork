import Foundation
import FirebaseFirestore

@MainActor
final class MessagesListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    private var listener: ListenerRegistration?

    func startObserving(uid: String) {
        listener = MessageRepository.shared.observeConversations(for: uid) { [weak self] conversations in
            self?.conversations = conversations
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func startConversation(currentUser: NodiUser, with otherUser: NodiUser) async -> Conversation? {
        try? await MessageRepository.shared.getOrCreateConversation(currentUser: currentUser, otherUser: otherUser)
    }

    deinit {
        listener?.remove()
    }
}
