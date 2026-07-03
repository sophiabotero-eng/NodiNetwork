import SwiftUI

@main
struct NodiApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = SessionStore()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .tint(NodiColor.accent)
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url: url, session: session)
                }
        }
    }
}
