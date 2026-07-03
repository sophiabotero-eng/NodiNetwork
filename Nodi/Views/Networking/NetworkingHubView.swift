import SwiftUI
import FirebaseFirestore

struct NetworkingHubView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var section: Section = .discover
    @State private var pendingRequestCount = 0
    @State private var requestListener: AutoRemovingListener?

    private enum Section: String, CaseIterable {
        case discover = "Discover"
        case connect = "Connect"
        case requests = "Requests"
        case network = "My Network"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { item in
                        Text(badgedTitle(for: item)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, NodiSpacing.lg)
                .padding(.top, NodiSpacing.sm)

                switch section {
                case .discover:
                    DiscoverView()
                case .connect:
                    ConnectView()
                case .requests:
                    ConnectionRequestsView()
                case .network:
                    ConnectionsListView()
                }
            }
            .background(NodiColor.background)
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { userId in
                ProfileView(userId: userId, isOwnProfile: userId == session.currentUser?.id)
            }
        }
        .onAppear {
            guard let uid = session.currentUser?.id else { return }
            requestListener = AutoRemovingListener(
                registration: ConnectionRepository.shared.observePendingRequestCount(for: uid) { count in
                    pendingRequestCount = count
                }
            )
        }
    }

    private func badgedTitle(for section: Section) -> String {
        guard section == .requests, pendingRequestCount > 0 else { return section.rawValue }
        return "\(section.rawValue) (\(pendingRequestCount))"
    }
}

/// Firestore's `ListenerRegistration` doesn't get torn down automatically
/// when a SwiftUI view disappears the way `@StateObject` deinit does —
/// wrapping it lets us rely on ARC to call `remove()` when the view goes
/// away instead of needing an explicit `.onDisappear`.
final class AutoRemovingListener {
    private let registration: ListenerRegistration
    init(registration: ListenerRegistration) {
        self.registration = registration
    }
    deinit {
        registration.remove()
    }
}
