import UIKit
import Firebase
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        configureFirestoreOfflineCache()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        application.registerForRemoteNotifications()

        return true
    }

    /// Firestore's on-disk persistence is what makes "offline caching"
    /// (Phase 5 polish item) real rather than aspirational: profiles,
    /// portfolios, and connections you've already loaded stay readable
    /// with no network, and writes made offline (e.g. sending a message
    /// in a dead zone) queue and flush automatically on reconnect. This
    /// must run before any other Firestore call in the app, which is why
    /// it's here immediately after `FirebaseApp.configure()`.
    private func configureFirestoreOfflineCache() {
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        Firestore.firestore().settings = settings
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - Push Notifications

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        NotificationRouter.shared.handle(userInfo: userInfo)
    }
}

// MARK: - FCM

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            await NotificationService.shared.registerFCMToken(fcmToken)
        }
    }
}
