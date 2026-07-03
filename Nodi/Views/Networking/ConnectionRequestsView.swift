import SwiftUI

@MainActor
final class ConnectionRequestsViewModel: ObservableObject {
    @Published var requests: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await ConnectionRepository.shared.fetchPendingRequests(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(_ connection: Connection, accept: Bool) async {
        guard let id = connection.id else { return }
        do {
            try await ConnectionRepository.shared.respond(to: id, accept: accept)
            requests.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ConnectionRequestsView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = ConnectionRequestsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.requests.isEmpty {
                ProgressView().padding(.top, NodiSpacing.xl)
            } else if viewModel.requests.isEmpty {
                EmptyStateView(
                    icon: "person.badge.clock",
                    title: "No pending requests",
                    message: "Connection requests from other creatives will show up here."
                )
            } else {
                List(viewModel.requests) { connection in
                    if let uid = session.currentUser?.id, let summary = connection.other(than: uid) {
                        RequestRow(summary: summary, type: connection.type) {
                            Task { await viewModel.respond(connection, accept: true) }
                        } onDecline: {
                            Task { await viewModel.respond(connection, accept: false) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            if let uid = session.currentUser?.id {
                await viewModel.load(uid: uid)
            }
        }
    }
}

private struct RequestRow: View {
    let summary: ConnectionParticipantSummary
    let type: ConnectionType
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: summary.photoURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.displayName).font(NodiFont.headline())
                Label(type.label, systemImage: type.icon)
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.secondaryText)
            }
            Spacer()
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
                    .background(NodiColor.secondaryBackground)
                    .clipShape(Circle())
            }
            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(NodiColor.accent)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}
