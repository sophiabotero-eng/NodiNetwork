import Foundation
import FirebaseFirestore

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NodiNotification] = []

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    private var listener: ListenerRegistration?

    func startObserving() {
        listener = NotificationService.shared.observeNotifications { [weak self] notifications in
            self?.notifications = notifications
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func markRead(_ notification: NodiNotification) {
        guard let id = notification.id, !notification.isRead else { return }
        Task { await NotificationService.shared.markNotificationRead(id) }
    }

    deinit {
        listener?.remove()
    }
}
