import SwiftUI

enum NodiTab: Hashable {
    case graph
    case discover
    case portfolio
    case messages
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selectedTab: NodiTab = .profile

    /// Owned here (not by `ConnectView`) and injected via environment so a
    /// connect link or NFC tag scan resolves to the confirm sheet no
    /// matter which tab is active when it arrives — the alternative
    /// (each view owning its own `ConnectViewModel`) only works while
    /// `ConnectView` happens to already be on screen.
    @StateObject private var connectViewModel = ConnectViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @ObservedObject private var nfcService = NFCConnectionService.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if let uid = session.currentUser?.id {
                    GraphView(centerUserId: uid, showsCloseButton: false)
                }
            }
            .tabItem { Label("Graph", systemImage: "circle.hexagongrid") }
            .tag(NodiTab.graph)

            NetworkingHubView()
                .tabItem { Label("Discover", systemImage: "sparkle.magnifyingglass") }
                .tag(NodiTab.discover)

            NavigationStack {
                Group {
                    if let uid = session.currentUser?.id {
                        ScrollView {
                            PortfolioGridView(ownerId: uid, isOwnProfile: true)
                                .padding(NodiSpacing.lg)
                        }
                    }
                }
                .background(NodiColor.background)
                .navigationTitle("Portfolio")
            }
            .tabItem { Label("Portfolio", systemImage: "square.grid.2x2") }
            .tag(NodiTab.portfolio)

            NavigationStack {
                ComingSoonView(
                    icon: "bubble.left.and.bubble.right",
                    title: "Messages",
                    message: "Direct and voice messaging arrive in Phase 5."
                )
                .navigationTitle("Messages")
            }
            .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
            .tag(NodiTab.messages)

            NavigationStack {
                if let uid = session.currentUser?.id {
                    ProfileView(userId: uid, isOwnProfile: true)
                }
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(NodiTab.profile)
        }
        .environmentObject(connectViewModel)
        .sheet(isPresented: $connectViewModel.showingConfirmSheet) {
            if let target = connectViewModel.resolvedTargetUser {
                ConnectionConfirmSheet(viewModel: connectViewModel, targetUser: target)
            }
        }
        .onChange(of: deepLinkRouter.pendingLink) { _, link in
            guard case .connect(let uid) = link, let url = URL(string: "https://nodi.app/connect/\(uid)") else { return }
            Task { await connectViewModel.resolve(url: url, source: .shareLink, currentUserId: session.currentUser?.id) }
            _ = deepLinkRouter.consumePendingLink()
        }
        .onChange(of: nfcService.lastScannedURL) { _, url in
            guard let url else { return }
            Task { await connectViewModel.resolve(url: url, source: .nfcTag, currentUserId: session.currentUser?.id) }
        }
    }
}

struct ComingSoonView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        EmptyStateView(icon: icon, title: title, message: message)
            .frame(maxHeight: .infinity)
            .background(NodiColor.background)
    }
}
