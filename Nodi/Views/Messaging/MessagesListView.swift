import SwiftUI

struct MessagesListView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = MessagesListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.conversations.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No messages yet",
                        message: "Start a conversation from someone's profile."
                    )
                } else {
                    List(viewModel.conversations) { conversation in
                        if let uid = session.currentUser?.id, let summary = conversation.other(than: uid) {
                            NavigationLink(value: conversation.id ?? "") {
                                ConversationRow(
                                    summary: summary,
                                    conversation: conversation,
                                    unreadCount: conversation.unreadCounts[uid] ?? 0
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(NodiColor.background)
            .navigationTitle("Messages")
            .navigationDestination(for: String.self) { conversationId in
                if let uid = session.currentUser?.id {
                    ChatView(conversationId: conversationId, currentUserId: uid)
                }
            }
        }
        .onAppear {
            if let uid = session.currentUser?.id {
                viewModel.startObserving(uid: uid)
            }
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }
}

private struct ConversationRow: View {
    let summary: ConnectionParticipantSummary
    let conversation: Conversation
    let unreadCount: Int

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: summary.photoURL, size: 52, isVerified: summary.isVerified)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.displayName).font(NodiFont.headline())
                Text(conversation.lastMessageText.isEmpty ? "Say hello 👋" : conversation.lastMessageText)
                    .font(NodiFont.subheadline())
                    .foregroundStyle(unreadCount > 0 ? NodiColor.primaryText : NodiColor.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastMessageAt.formatted(.relative(presentation: .numeric)))
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.tertiaryText)
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(NodiFont.caption(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(NodiColor.accent, in: Capsule())
                }
            }
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}
