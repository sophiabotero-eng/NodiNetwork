import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

/// Client-side half of push notifications. The actual "send a push when X
/// happens" logic lives in Cloud Functions (see /functions) — this service
/// only requests permission, keeps the user's FCM token list in Firestore
/// current, and marks in-app notification documents as read.
final class NotificationService {

    static let shared = NotificationService()
    private let db = Firestore.firestore()
    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Called from `AppDelegate.messaging(_:didReceiveRegistrationToken:)`.
    /// Tokens are stored as an array (a user may have several devices) and
    /// deduplicated server-side is unnecessary since Firestore `arrayUnion`
    /// already dedupes.
    func registerFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ])
    }

    func unregisterFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid).updateData([
            "fcmTokens": FieldValue.arrayRemove([token])
        ])
    }

    func markNotificationRead(_ notificationId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid)
            .collection("notifications").document(notificationId)
            .updateData(["isRead": true])
    }

    func observeNotifications(onChange: @escaping ([NodiNotification]) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                let notifications = snapshot?.documents.compactMap {
                    try? $0.data(as: NodiNotification.self)
                } ?? []
                onChange(notifications)
            }
    }
}

/// Handles the user tapping a delivered push notification and turning its
/// payload into in-app navigation via `DeepLinkRouter`.
@MainActor
enum NotificationRouter {
    static var shared = NotificationRouterBox()
}

@MainActor
final class NotificationRouterBox {
    func handle(userInfo: [AnyHashable: Any]) {
        guard let urlString = userInfo["deepLinkURL"] as? String,
              let url = URL(string: urlString) else { return }
        DeepLinkRouter.shared.pendingLink = NodiDeepLink(url: url)
    }
}
