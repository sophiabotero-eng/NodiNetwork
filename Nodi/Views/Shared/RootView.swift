import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            switch session.authState {
            case .loading:
                SplashView()
            case .signedOut:
                AuthWelcomeView()
            case .needsOnboarding:
                OnboardingFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(NodiAnimation.spring, value: session.authState)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            NodiColor.background.ignoresSafeArea()
            VStack(spacing: NodiSpacing.md) {
                NodiLogoMark(size: 64)
                ProgressView()
                    .tint(NodiColor.accent)
            }
        }
    }
}
