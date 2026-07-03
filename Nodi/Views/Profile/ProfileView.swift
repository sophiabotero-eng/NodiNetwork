import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject private var connectViewModel: ConnectViewModel
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingNotifications = false

    init(userId: String, isOwnProfile: Bool) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId, isOwnProfile: isOwnProfile))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, NodiSpacing.md)

                if let user = viewModel.user {
                    VStack(alignment: .leading, spacing: NodiSpacing.md) {
                        identityBlock(user)
                        statsRow(user)
                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(NodiFont.body())
                                .foregroundStyle(NodiColor.primaryText)
                        }
                        infoRows(user)
                        socialLinksRow(user)

                        if !user.softwareUsed.isEmpty {
                            softwareSection(user)
                        }

                        PortfolioGridView(ownerId: viewModel.userId, isOwnProfile: viewModel.isOwnProfile)
                            .padding(.top, NodiSpacing.sm)
                    }
                    .padding(.horizontal, NodiSpacing.lg)
                } else if viewModel.isLoading {
                    ProgressView().padding(.top, NodiSpacing.xxl)
                }
            }
        }
        .background(NodiColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwnProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                            if notificationsViewModel.unreadCount > 0 {
                                Circle().fill(NodiColor.danger).frame(width: 8, height: 8).offset(x: 4, y: -2)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            if let user = viewModel.user {
                EditProfileView(user: user)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .onAppear {
            viewModel.startObserving()
            Task { await viewModel.loadFollowState(currentUserId: session.currentUser?.id) }
            if viewModel.isOwnProfile {
                notificationsViewModel.startObserving()
            }
        }
        .onDisappear {
            if viewModel.isOwnProfile {
                notificationsViewModel.stopObserving()
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(urlString: viewModel.user?.coverImageURL) {
                LinearGradient(
                    colors: [NodiColor.accent.opacity(0.5), NodiColor.secondaryBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: 180)
            .clipped()

            NodiAvatarView(
                urlString: viewModel.user?.profilePhotoURL,
                size: 88,
                showsOnlineIndicator: false,
                isVerified: viewModel.user?.isVerified ?? false
            )
            .overlay(Circle().stroke(NodiColor.background, lineWidth: 4))
            .offset(x: NodiSpacing.lg, y: 44)
        }
        .padding(.bottom, 44)
    }

    private func identityBlock(_ user: NodiUser) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: NodiSpacing.xs) {
                    Text(user.displayName)
                        .font(NodiFont.title())
                        .foregroundStyle(NodiColor.primaryText)
                    AvailabilityDot(status: user.availability)
                }
                Text("@\(user.username)")
                    .font(NodiFont.subheadline())
                    .foregroundStyle(NodiColor.secondaryText)
            }
            Spacer()
            if viewModel.isOwnProfile {
                NodiButton(title: "Edit Profile", kind: .secondary) {
                    showingEditProfile = true
                }
                .fixedSize()
            } else {
                HStack(spacing: NodiSpacing.xs) {
                    NodiButton(title: "Connect", kind: .secondary) {
                        connectViewModel.resolvedTargetUser = user
                        connectViewModel.resolvedSource = .manualRequest
                        connectViewModel.showingConfirmSheet = true
                    }
                    .fixedSize()

                    NodiButton(
                        title: viewModel.isFollowing ? "Following" : "Follow",
                        kind: viewModel.isFollowing ? .secondary : .primary,
                        isLoading: viewModel.isUpdatingFollow
                    ) {
                        Task { await viewModel.toggleFollow(currentUserId: session.currentUser?.id) }
                    }
                    .fixedSize()
                }
            }
        }
    }

    private func statsRow(_ user: NodiUser) -> some View {
        HStack(spacing: NodiSpacing.lg) {
            StatColumn(value: user.projectCount, label: "Projects")
            StatColumn(value: user.connectionCount, label: "Connections")
            StatColumn(value: user.followerCount, label: "Followers")
            StatColumn(value: user.followingCount, label: "Following")
        }
    }

    private func infoRows(_ user: NodiUser) -> some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
            if !user.profession.isEmpty {
                Label(user.profession, systemImage: "paintbrush")
            }
            if !user.location.isEmpty {
                Label(user.location, systemImage: "mappin.and.ellipse")
            }
        }
        .font(NodiFont.subheadline())
        .foregroundStyle(NodiColor.secondaryText)
    }

    @ViewBuilder
    private func socialLinksRow(_ user: NodiUser) -> some View {
        let links: [(String, String, String)] = [
            (user.website, "safari", "https://\(user.website)"),
            (user.instagramHandle, "camera", "https://instagram.com/\(user.instagramHandle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"),
            (user.linkedInHandle, "briefcase", "https://linkedin.com/\(user.linkedInHandle)"),
            (user.behanceHandle, "paintpalette", "https://behance.net/\(user.behanceHandle)")
        ].filter { !$0.0.isEmpty }

        if !links.isEmpty {
            HStack(spacing: NodiSpacing.md) {
                ForEach(links, id: \.0) { link in
                    if let url = URL(string: link.2) {
                        Link(destination: url) {
                            Image(systemName: link.1)
                                .font(.system(size: 16))
                                .foregroundStyle(NodiColor.accent)
                                .frame(width: 36, height: 36)
                                .background(NodiColor.secondaryBackground)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
    }

    private func softwareSection(_ user: NodiUser) -> some View {
        FlowLayout(spacing: NodiSpacing.xs) {
            ForEach(user.softwareUsed, id: \.self) { software in
                Text(software)
                    .font(NodiFont.caption())
                    .padding(.horizontal, NodiSpacing.sm)
                    .padding(.vertical, 6)
                    .background(NodiColor.secondaryBackground)
                    .clipShape(Capsule())
                    .foregroundStyle(NodiColor.secondaryText)
            }
        }
    }
}

private struct StatColumn: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(NodiFont.headline())
                .foregroundStyle(NodiColor.primaryText)
            Text(label)
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.secondaryText)
        }
    }
}

private struct AvailabilityDot: View {
    let status: AvailabilityStatus

    var color: Color {
        switch status {
        case .open: return NodiColor.success
        case .selective: return NodiColor.warning
        case .unavailable: return NodiColor.tertiaryText
        }
    }

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

#Preview {
    NavigationStack {
        ProfileView(userId: "preview", isOwnProfile: true)
            .environmentObject(SessionStore())
            .environmentObject(ConnectViewModel())
    }
}
