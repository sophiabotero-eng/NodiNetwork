import Foundation
import FirebaseFirestoreSwift

enum NotificationKind: String, Codable {
    case newFollower
    case connectionRequest
    case connectionAccepted
    case newMessage
    case mention
    case eventInvite
    case recommendation
}

/// Stored at `users/{uid}/notifications/{id}`. Written by Cloud Functions
/// in response to Firestore triggers (see /functions/src/notifications.ts).
struct NodiNotification: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var kind: NotificationKind
    var actorId: String
    var actorDisplayName: String
    var actorPhotoURL: String?
    var message: String
    var deepLinkURL: String?
    var isRead: Bool
    var createdAt: Date
}
