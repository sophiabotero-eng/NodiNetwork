import SwiftUI

@MainActor
final class ConnectionsListViewModel: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            connections = try await ConnectionRepository.shared.fetchConnections(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ConnectionsListView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = ConnectionsListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.connections.isEmpty {
                ProgressView().padding(.top, NodiSpacing.xl)
            } else if viewModel.connections.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No connections yet",
                    message: "Tap Connect to meet other creatives via QR code, NFC, or a shareable link."
                )
            } else {
                List(viewModel.connections) { connection in
                    if let uid = session.currentUser?.id, let summary = connection.other(than: uid), let otherId = connection.otherId(than: uid) {
                        NavigationLink(value: otherId) {
                            ConnectionRow(summary: summary, type: connection.type)
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

private struct ConnectionRow: View {
    let summary: ConnectionParticipantSummary
    let type: ConnectionType

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: summary.photoURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.displayName).font(NodiFont.headline())
                Text(summary.profession.isEmpty ? type.label : "\(summary.profession) · \(type.label)")
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.secondaryText)
            }
            Spacer()
            Image(systemName: type.icon).foregroundStyle(type.edgeColor)
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}
