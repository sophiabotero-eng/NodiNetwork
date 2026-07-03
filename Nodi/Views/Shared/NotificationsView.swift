import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell",
                        title: "No notifications yet",
                        message: "Follows, connection requests, and messages will show up here."
                    )
                } else {
                    List(viewModel.notifications) { notification in
                        Button {
                            viewModel.markRead(notification)
                            if let urlString = notification.deepLinkURL, let url = URL(string: urlString) {
                                deepLinkRouter.pendingLink = NodiDeepLink(url: url)
                                dismiss()
                            }
                        } label: {
                            NotificationRow(notification: notification)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(NodiColor.background)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }
}

private struct NotificationRow: View {
    let notification: NodiNotification

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: notification.actorPhotoURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(NodiFont.subheadline())
                    .foregroundStyle(NodiColor.primaryText)
                Text(notification.createdAt.formatted(.relative(presentation: .named)))
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.tertiaryText)
            }
            Spacer()
            if !notification.isRead {
                Circle().fill(NodiColor.accent).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}
