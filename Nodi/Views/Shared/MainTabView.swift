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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ComingSoonView(
                    icon: "circle.hexagongrid",
                    title: "Network Graph",
                    message: "Your interactive connection graph arrives in Phase 4."
                )
                .navigationTitle("Graph")
            }
            .tabItem { Label("Graph", systemImage: "circle.hexagongrid") }
            .tag(NodiTab.graph)

            NavigationStack {
                ComingSoonView(
                    icon: "sparkle.magnifyingglass",
                    title: "Discover",
                    message: "Nearby creatives, search, and filters arrive in Phase 3."
                )
                .navigationTitle("Discover")
            }
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
