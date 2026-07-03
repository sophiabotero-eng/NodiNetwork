import Foundation
import FirebaseFirestoreSwift

/// Top-level `conversations/{uidA_uidB}` — 1:1 direct messages only, per
/// the spec ("Messaging: direct messages, voice messages..."). Same
/// deterministic sorted-pair doc ID pattern as Connection/Follow.
struct Conversation: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var participantIds: [String]
    var participants: [String: ConnectionParticipantSummary]

    var lastMessageText: String
    var lastMessageSenderId: String?
    var lastMessageAt: Date

    /// uid -> number of unread messages *for that uid*. Only the
    /// recipient's own count is ever decremented client-side (to zero, on
    /// opening the thread); the sender's increment happens via
    /// onMessageCreated (Cloud Function) so two devices sending
    /// concurrently can't race a client-computed increment.
    var unreadCounts: [String: Int]

    /// uids currently typing. Each client sets/clears its own entry;
    /// there's no server-side TTL sweep, so `ChatViewModel` also clears
    /// it locally after a few seconds of silence to avoid a stuck
    /// indicator if a client disconnects mid-type.
    var typingUserIds: [String]

    var createdAt: Date

    static func documentId(for uidA: String, _ uidB: String) -> String {
        [uidA, uidB].sorted().joined(separator: "_")
    }

    func other(than uid: String) -> ConnectionParticipantSummary? {
        guard let otherId = participantIds.first(where: { $0 != uid }) else { return nil }
        return participants[otherId]
    }

    func otherId(than uid: String) -> String? {
        participantIds.first(where: { $0 != uid })
    }
}

enum MessageType: String, Codable {
    case text
    case voice
}

/// `conversations/{id}/messages/{messageId}`.
struct ChatMessage: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var type: MessageType
    var text: String?
    var voiceURL: String?
    var voiceDurationSeconds: Double?
    var createdAt: Date
    var readBy: [String]
}
