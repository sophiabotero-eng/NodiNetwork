import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var connectViewModel: ConnectViewModel
    @StateObject private var viewModel = RecommendationsViewModel()

    var body: some View {
        Group {
            if viewModel.recommendations.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    title: "No suggestions yet",
                    message: "As you connect with more creatives, Nodi will suggest people who share your tools, profession, or mutual connections.",
                    actionTitle: "Refresh"
                ) {
                    Task { await viewModel.refresh() }
                }
            } else {
                List(viewModel.recommendations) { recommendation in
                    RecommendationRow(recommendation: recommendation) {
                        Task { await connect(to: recommendation) }
                    } onDismiss: {
                        guard let uid = session.currentUser?.id else { return }
                        Task { await viewModel.dismiss(uid: uid, recommendation: recommendation) }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        }
        .task {
            if let uid = session.currentUser?.id {
                viewModel.startObserving(uid: uid)
                await viewModel.refresh()
            }
        }
        .onDisappear { viewModel.stopObserving() }
    }

    private func connect(to recommendation: ConnectionRecommendation) async {
        guard let user = try? await UserRepository.shared.fetchUser(uid: recommendation.candidateId) else { return }
        connectViewModel.resolvedTargetUser = user
        connectViewModel.resolvedSource = .manualRequest
        connectViewModel.showingConfirmSheet = true
    }
}

private struct RecommendationRow: View {
    let recommendation: ConnectionRecommendation
    let onConnect: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: recommendation.profilePhotoURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.displayName).font(NodiFont.headline())
                if let reason = recommendation.reasons.first {
                    Text(reason).font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
                }
            }
            Spacer()
            Button("Connect", action: onConnect)
                .font(NodiFont.caption(.semibold))
                .padding(.horizontal, NodiSpacing.sm)
                .padding(.vertical, 6)
                .background(NodiColor.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .padding(.vertical, NodiSpacing.xxs)
        .swipeActions {
            Button("Dismiss", role: .destructive, action: onDismiss)
        }
    }
}
