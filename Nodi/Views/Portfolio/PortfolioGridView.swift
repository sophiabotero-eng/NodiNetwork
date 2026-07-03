import SwiftUI

struct PortfolioGridView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: PortfolioViewModel
    @State private var selectedSegment: Segment = .published
    @State private var showingEditor = false
    @State private var selectedProject: PortfolioProject?

    private enum Segment: String, CaseIterable {
        case published = "Published"
        case drafts = "Drafts"
    }

    let ownerId: String
    let isOwnProfile: Bool

    init(ownerId: String, isOwnProfile: Bool) {
        self.ownerId = ownerId
        self.isOwnProfile = isOwnProfile
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(ownerId: ownerId, isOwnProfile: isOwnProfile))
    }

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.sm) {
            HStack {
                Text("Portfolio")
                    .font(NodiFont.title2())
                    .foregroundStyle(NodiColor.primaryText)
                Spacer()
                if isOwnProfile {
                    Button {
                        selectedProject = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(NodiColor.accent)
                    }
                }
            }

            if isOwnProfile {
                Picker("", selection: $selectedSegment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            let projects = isOwnProfile && selectedSegment == .drafts ? viewModel.draftProjects : viewModel.publishedProjects

            if viewModel.isLoading && projects.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(NodiSpacing.xl)
            } else if projects.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: selectedSegment == .drafts ? "No drafts" : "No projects yet",
                    message: isOwnProfile ? "Tap + to add your first project." : "This creative hasn't published any work yet.",
                    actionTitle: isOwnProfile ? "New Project" : nil
                ) {
                    selectedProject = nil
                    showingEditor = true
                }
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(projects) { project in
                        ProjectGridTile(project: project)
                            .aspectRatio(1, contentMode: .fill)
                            .onTapGesture {
                                selectedProject = project
                            }
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            Task { await viewModel.load() }
        }) {
            if let user = session.currentUser {
                ProjectEditorView(owner: user, existing: nil)
            }
        }
        .fullScreenCover(item: $selectedProject) { project in
            ProjectDetailView(project: project, canEdit: isOwnProfile, onDeleted: {
                Task { await viewModel.load() }
            })
        }
    }
}

private struct ProjectGridTile: View {
    let project: PortfolioProject

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                RemoteImage(urlString: project.coverImageURL) {
                    NodiColor.secondaryBackground
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()

                if project.mediaItems.count > 1 {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(6)
                }

                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)
                    .frame(height: proxy.size.height * 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Text(project.title)
                    .font(NodiFont.caption(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
    }
}
