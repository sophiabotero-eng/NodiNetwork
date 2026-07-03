import SwiftUI

/// Shared confirm-and-send-request sheet used both after resolving a
/// scanned/tapped connect link (`ConnectView`) and when initiating a
/// connection request directly from someone's profile (`ProfileView`).
struct ConnectionConfirmSheet: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject var viewModel: ConnectViewModel
    let targetUser: NodiUser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: NodiSpacing.lg) {
                NodiAvatarView(urlString: targetUser.profilePhotoURL, size: 84, isVerified: targetUser.isVerified)
                VStack(spacing: 2) {
                    Text(targetUser.displayName).font(NodiFont.title2())
                    Text("@\(targetUser.username)").font(NodiFont.subheadline()).foregroundStyle(NodiColor.secondaryText)
                    if !targetUser.profession.isEmpty {
                        Text(targetUser.profession).font(NodiFont.caption()).foregroundStyle(NodiColor.tertiaryText)
                    }
                }

                VStack(alignment: .leading, spacing: NodiSpacing.xs) {
                    Text("HOW DO YOU KNOW THEM?").font(NodiFont.caption(.semibold)).foregroundStyle(NodiColor.secondaryText)
                    FlowLayout(spacing: NodiSpacing.xs) {
                        ForEach(ConnectionType.allCases) { type in
                            Button {
                                viewModel.selectedType = type
                            } label: {
                                Label(type.label, systemImage: type.icon)
                                    .font(NodiFont.subheadline())
                                    .padding(.horizontal, NodiSpacing.sm)
                                    .padding(.vertical, NodiSpacing.xxs)
                                    .background(viewModel.selectedType == type ? NodiColor.accent : NodiColor.secondaryBackground)
                                    .foregroundStyle(viewModel.selectedType == type ? .white : NodiColor.primaryText)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                NodiButton(
                    title: viewModel.resolvedSource == .nfcTag ? "Connect" : "Send Request",
                    isLoading: viewModel.isSendingRequest
                ) {
                    guard let currentUser = session.currentUser else { return }
                    Task {
                        await viewModel.confirmConnection(currentUser: currentUser)
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }

                Spacer()
            }
            .padding(NodiSpacing.lg)
            .background(NodiColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
