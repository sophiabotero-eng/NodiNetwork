import SwiftUI
import AVKit
import PDFKit

struct ProjectDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var project: PortfolioProject
    let canEdit: Bool
    let onDeleted: () -> Void

    @State private var showingEditor = false
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NodiSpacing.md) {
                    mediaPager

                    VStack(alignment: .leading, spacing: NodiSpacing.md) {
                        HStack {
                            NodiAvatarView(urlString: project.ownerPhotoURL, size: 36)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(project.ownerDisplayName).font(NodiFont.subheadline(.semibold))
                                Text("@\(project.ownerUsername)").font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
                            }
                            Spacer()
                            Text(String(project.year)).font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
                        }

                        Text(project.title)
                            .font(NodiFont.title())
                            .foregroundStyle(NodiColor.primaryText)

                        if !project.projectDescription.isEmpty {
                            Text(project.projectDescription)
                                .font(NodiFont.body())
                                .foregroundStyle(NodiColor.secondaryText)
                        }

                        if !project.tags.isEmpty {
                            FlowLayout(spacing: NodiSpacing.xs) {
                                ForEach(project.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(NodiFont.caption())
                                        .padding(.horizontal, NodiSpacing.sm)
                                        .padding(.vertical, 6)
                                        .background(NodiColor.secondaryBackground)
                                        .clipShape(Capsule())
                                        .foregroundStyle(NodiColor.accent)
                                }
                            }
                        }

                        if !project.softwareUsed.isEmpty {
                            metadataRow(label: "Software", value: project.softwareUsed.joined(separator: ", "))
                        }
                        if !project.collaboratorNames.isEmpty {
                            metadataRow(label: "Collaborators", value: project.collaboratorNames.joined(separator: ", "))
                        }
                        metadataRow(label: "Views", value: "\(project.viewCount)")
                    }
                    .padding(.horizontal, NodiSpacing.lg)
                }
                .padding(.bottom, NodiSpacing.xl)
            }
            .background(NodiColor.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") { showingEditor = true }
                    }
                }
            }
            .sheet(isPresented: $showingEditor, onDismiss: {
                Task { await reload() }
            }) {
                if let user = session.currentUser {
                    ProjectEditorView(owner: user, existing: project)
                }
            }
            .task {
                if let id = project.id {
                    await ProjectRepository.shared.incrementViewCount(projectId: id)
                }
            }
        }
    }

    private var mediaPager: some View {
        TabView {
            ForEach(project.mediaItems.sorted(by: { $0.order < $1.order })) { item in
                ProjectMediaView(item: item)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 420)
        .background(Color.black)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(NodiFont.caption(.semibold))
                .foregroundStyle(NodiColor.tertiaryText)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(NodiFont.subheadline())
                .foregroundStyle(NodiColor.primaryText)
        }
    }

    private func reload() async {
        guard let id = project.id, let refreshed = try? await ProjectRepository.shared.fetchProject(id: id) else {
            onDeleted()
            return
        }
        project = refreshed
    }
}

private struct ProjectMediaView: View {
    let item: ProjectMediaItem

    var body: some View {
        switch item.kind {
        case .image:
            RemoteImage(urlString: item.url) {
                NodiColor.secondaryBackground
            }
            .aspectRatio(contentMode: .fit)
        case .video:
            if let url = URL(string: item.url) {
                VideoPlayer(player: AVPlayer(url: url))
            }
        case .pdf:
            if let url = URL(string: item.url) {
                PDFKitView(url: url)
            }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

#Preview {
    ProjectDetailView(
        project: .draft(owner: .draft(uid: "u1", email: "a@b.com", displayName: "Ada", providers: [.email])),
        canEdit: true,
        onDeleted: {}
    )
    .environmentObject(SessionStore())
}
