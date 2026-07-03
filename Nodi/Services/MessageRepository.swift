import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

/// `unreadCounts` increments happen in the onMessageCreated Cloud
/// Function (Admin SDK, bypasses rules) for the same reason connection
/// counters do — see firestore.rules. The client only ever zeroes its
/// *own* count when opening a thread.
final class MessageRepository {

    static let shared = MessageRepository()

    private let db = Firestore.firestore()
    private init() {}

    private var conversationsCollection: CollectionReference { db.collection("conversations") }

    func getOrCreateConversation(currentUser: NodiUser, otherUser: NodiUser) async throws -> Conversation {
        guard let currentId = currentUser.id, let otherId = otherUser.id else {
            throw MessageRepositoryError.missingUser
        }
        let docId = Conversation.documentId(for: currentId, otherId)
        let ref = conversationsCollection.document(docId)
        let snapshot = try await ref.getDocument()

        if snapshot.exists, let existing = try? snapshot.data(as: Conversation.self) {
            return existing
        }

        let conversation = Conversation(
            id: docId,
            participantIds: [currentId, otherId].sorted(),
            participants: [
                currentId: ConnectionParticipantSummary(displayName: currentUser.displayName, username: currentUser.username, photoURL: currentUser.profilePhotoURL, profession: currentUser.profession, isVerified: currentUser.isVerified),
                otherId: ConnectionParticipantSummary(displayName: otherUser.displayName, username: otherUser.username, photoURL: otherUser.profilePhotoURL, profession: otherUser.profession, isVerified: otherUser.isVerified)
            ],
            lastMessageText: "",
            lastMessageSenderId: nil,
            lastMessageAt: Date(),
            unreadCounts: [currentId: 0, otherId: 0],
            typingUserIds: [],
            createdAt: Date()
        )
        try await ref.setData(from: conversation, merge: false)
        return conversation
    }

    func sendTextMessage(conversationId: String, senderId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = ChatMessage(senderId: senderId, type: .text, text: trimmed, voiceURL: nil, voiceDurationSeconds: nil, createdAt: Date(), readBy: [senderId])
        try await send(message, conversationId: conversationId, preview: trimmed, senderId: senderId)
    }

    func sendVoiceMessage(conversationId: String, senderId: String, url: URL, durationSeconds: Double) async throws {
        let message = ChatMessage(senderId: senderId, type: .voice, text: nil, voiceURL: url.absoluteString, voiceDurationSeconds: durationSeconds, createdAt: Date(), readBy: [senderId])
        try await send(message, conversationId: conversationId, preview: "🎤 Voice message", senderId: senderId)
    }

    private func send(_ message: ChatMessage, conversationId: String, preview: String, senderId: String) async throws {
        let conversationRef = conversationsCollection.document(conversationId)
        _ = try await conversationRef.collection("messages").addDocument(from: message)
        try await conversationRef.updateData([
            "lastMessageText": preview,
            "lastMessageSenderId": senderId,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "typingUserIds": FieldValue.arrayRemove([senderId])
        ])
    }

    func markRead(conversationId: String, uid: String) async {
        try? await conversationsCollection.document(conversationId).updateData([
            "unreadCounts.\(uid)": 0
        ])
    }

    func setTyping(conversationId: String, uid: String, isTyping: Bool) {
        let field: Any = isTyping ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
        conversationsCollection.document(conversationId).updateData(["typingUserIds": field])
    }

    func observeConversations(for uid: String, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        conversationsCollection
            .whereField("participantIds", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let conversations = snapshot?.documents.compactMap { try? $0.data(as: Conversation.self) } ?? []
                onChange(conversations)
            }
    }

    func observeConversation(id: String, onChange: @escaping (Conversation?) -> Void) -> ListenerRegistration {
        conversationsCollection.document(id).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            onChange(try? snapshot.data(as: Conversation.self))
        }
    }

    func observeMessages(conversationId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        conversationsCollection.document(conversationId).collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: 200)
            .addSnapshotListener { snapshot, _ in
                let messages = snapshot?.documents.compactMap { try? $0.data(as: ChatMessage.self) } ?? []
                onChange(messages)
            }
    }

    func markMessagesRead(conversationId: String, messages: [ChatMessage], uid: String) {
        let unread = messages.filter { !$0.readBy.contains(uid) && $0.senderId != uid }
        guard !unread.isEmpty else { return }
        let batch = db.batch()
        let messagesRef = conversationsCollection.document(conversationId).collection("messages")
        for message in unread {
            guard let id = message.id else { continue }
            batch.updateData(["readBy": FieldValue.arrayUnion([uid])], forDocument: messagesRef.document(id))
        }
        batch.commit()
    }
}

enum MessageRepositoryError: LocalizedError {
    case missingUser
    var errorDescription: String? { "Couldn't start that conversation." }
}
