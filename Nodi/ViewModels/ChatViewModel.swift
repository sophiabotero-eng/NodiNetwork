import Foundation
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var conversation: Conversation?
    @Published var draftText = ""
    @Published var errorMessage: String?

    let conversationId: String
    let currentUserId: String

    private var messagesListener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?
    private var typingClearTask: Task<Void, Never>?

    init(conversationId: String, currentUserId: String) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
    }

    deinit {
        messagesListener?.remove()
        conversationListener?.remove()
    }

    var isOtherTyping: Bool {
        (conversation?.typingUserIds ?? []).contains { $0 != currentUserId }
    }

    func startObserving() {
        messagesListener = MessageRepository.shared.observeMessages(conversationId: conversationId) { [weak self] messages in
            guard let self else { return }
            self.messages = messages
            MessageRepository.shared.markMessagesRead(conversationId: self.conversationId, messages: messages, uid: self.currentUserId)
        }
        conversationListener = MessageRepository.shared.observeConversation(id: conversationId) { [weak self] conversation in
            self?.conversation = conversation
        }
        Task { await MessageRepository.shared.markRead(conversationId: conversationId, uid: currentUserId) }
    }

    func stopObserving() {
        messagesListener?.remove()
        conversationListener?.remove()
        setTyping(false)
    }

    func sendText() async {
        let text = draftText
        draftText = ""
        setTyping(false)
        do {
            try await MessageRepository.shared.sendTextMessage(conversationId: conversationId, senderId: currentUserId, text: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendVoiceMessage(url: URL, duration: TimeInterval) async {
        do {
            let uploadURL = try await StorageService.shared.uploadData(
                Data(contentsOf: url),
                kind: .voiceMessage,
                ownerId: currentUserId
            )
            try await MessageRepository.shared.sendVoiceMessage(
                conversationId: conversationId,
                senderId: currentUserId,
                url: uploadURL,
                durationSeconds: duration
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onDraftChanged() {
        setTyping(true)
        typingClearTask?.cancel()
        typingClearTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            setTyping(false)
        }
    }

    private func setTyping(_ isTyping: Bool) {
        MessageRepository.shared.setTyping(conversationId: conversationId, uid: currentUserId, isTyping: isTyping)
    }
}
