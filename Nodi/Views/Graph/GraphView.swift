import SwiftUI

struct GraphView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: GraphViewModel
    @State private var camera = GraphCamera()
    @State private var showingFilters = false
    @State private var centerUser: NodiUser?
    @Environment(\.dismiss) private var dismiss

    /// Animated from 0 -> 1 on appear (see doc comment on
    /// `ProfileView.graphEntryGesture`) to approximate "profile collapses
    /// into a node" as a coordinated scale/fade rather than true
    /// cross-presentation shared-element geometry.
    @State private var appearProgress: CGFloat = 0

    /// False when this is the always-on Graph tab (nothing to dismiss
    /// back to); true when pushed from a profile's pinch/button entry
    /// point as a `fullScreenCover`.
    let showsCloseButton: Bool

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var showingAccessibleList = false

    init(centerUserId: String, showsCloseButton: Bool = true) {
        _viewModel = StateObject(wrappedValue: GraphViewModel(centerUserId: centerUserId))
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        ZStack {
            // `Canvas` has no built-in accessibility tree — VoiceOver
            // cannot inspect or activate individual shapes it draws, a
            // known SwiftUI limitation, not an oversight here. Rather
            // than ship a signature feature that's silently unusable
            // without sight, an equivalent list view (`GraphAccessibleListView`)
            // is offered as an explicit, discoverable alternative,
            // surfaced automatically when VoiceOver is running.
            GraphCanvasView(viewModel: viewModel, camera: $camera) { node in
                viewModel.select(node)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack {
                topBar
                Spacer()
                if viewModel.isLoading {
                    ProgressView().padding(NodiSpacing.sm).background(NodiColor.elevatedSurface, in: Capsule())
                }
                zoomLevelIndicator
            }
            .padding(NodiSpacing.md)
        }
        .background(NodiColor.background)
        .scaleEffect(0.85 + 0.15 * appearProgress)
        .opacity(appearProgress)
        .onAppear {
            withAnimation(NodiAnimation.graphTransition) {
                appearProgress = 1
            }
            if voiceOverEnabled {
                showingAccessibleList = true
            }
        }
        .task {
            guard let user = session.currentUser, user.id == viewModel.centerUserId else {
                if let fetched = try? await UserRepository.shared.fetchUser(uid: viewModel.centerUserId) {
                    centerUser = fetched
                    await viewModel.loadInitial(centerUser: fetched)
                }
                return
            }
            centerUser = user
            await viewModel.loadInitial(centerUser: user)
        }
        .sheet(item: $viewModel.selectedNode) { node in
            GraphNodePreviewSheet(node: node)
        }
        .sheet(isPresented: $showingFilters) {
            GraphFiltersSheet(activeFilters: $viewModel.activeFilters)
        }
        .sheet(isPresented: $showingAccessibleList) {
            GraphAccessibleListView(viewModel: viewModel)
        }
    }

    private var topBar: some View {
        HStack(spacing: NodiSpacing.sm) {
            if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .padding(10)
                        .background(NodiColor.elevatedSurface, in: Circle())
                }
            }

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(NodiColor.secondaryText)
                TextField("Search the graph", text: $viewModel.searchQuery)
                    .font(NodiFont.subheadline())
            }
            .padding(.horizontal, NodiSpacing.sm)
            .padding(.vertical, 10)
            .background(NodiColor.elevatedSurface)
            .clipShape(Capsule())

            Button {
                showingFilters = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle\(viewModel.activeFilters.isEmpty ? "" : ".fill")")
                    .padding(10)
                    .background(NodiColor.elevatedSurface, in: Circle())
            }

            Button {
                showingAccessibleList = true
            } label: {
                Image(systemName: "list.bullet")
                    .padding(10)
                    .background(NodiColor.elevatedSurface, in: Circle())
            }
            .accessibilityLabel("View graph as a list")
        }
        .foregroundStyle(NodiColor.primaryText)
    }

    private var zoomLevelIndicator: some View {
        HStack(spacing: NodiSpacing.xs) {
            ForEach(GraphZoomLevel.allCases, id: \.rawValue) { level in
                Button {
                    Task { await viewModel.setZoomLevel(level) }
                } label: {
                    Text(level.title)
                        .font(NodiFont.caption(.semibold))
                        .padding(.horizontal, NodiSpacing.sm)
                        .padding(.vertical, 6)
                        .background(viewModel.zoomLevel == level ? NodiColor.accent : NodiColor.elevatedSurface)
                        .foregroundStyle(viewModel.zoomLevel == level ? .white : NodiColor.secondaryText)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct GraphNodePreviewSheet: View {
    let node: GraphNode
    @Environment(\.dismiss) private var dismiss
    @State private var openFullProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: NodiSpacing.lg) {
                NodiAvatarView(urlString: node.photoURL, size: 88, showsOnlineIndicator: true, isOnline: node.isOnline, isVerified: node.isVerified)
                VStack(spacing: 2) {
                    Text(node.displayName).font(NodiFont.title2())
                    if !node.username.isEmpty {
                        Text("@\(node.username)").font(NodiFont.subheadline()).foregroundStyle(NodiColor.secondaryText)
                    }
                    if !node.profession.isEmpty {
                        Text(node.profession).font(NodiFont.caption()).foregroundStyle(NodiColor.tertiaryText)
                    }
                }
                NodiButton(title: "View Full Profile") {
                    openFullProfile = true
                }
                Spacer()
            }
            .padding(NodiSpacing.xl)
            .background(NodiColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $openFullProfile) {
                ProfileView(userId: node.id, isOwnProfile: false)
            }
        }
        .presentationDetents([.medium])
    }
}

/// The VoiceOver-accessible equivalent of the Canvas-rendered graph — see
/// the doc comment on `GraphView.body`. Grouped by depth so the
/// "single profile / direct connections / friends of friends / full
/// ecosystem" structure is still legible without the spatial layout.
private struct GraphAccessibleListView: View {
    @ObservedObject var viewModel: GraphViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var openProfileId: String?

    private var nodesByDepth: [Int: [GraphNode]] {
        Dictionary(grouping: viewModel.nodes, by: \.depth)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(nodesByDepth.keys.sorted(), id: \.self) { depth in
                    Section(depth == 0 ? "You" : "\(depth) hop\(depth == 1 ? "" : "s") away") {
                        ForEach(nodesByDepth[depth] ?? []) { node in
                            Button {
                                if node.isCluster {
                                    viewModel.expandCluster(node)
                                } else {
                                    openProfileId = node.id
                                }
                            } label: {
                                HStack {
                                    NodiAvatarView(urlString: node.photoURL, size: 40, showsOnlineIndicator: true, isOnline: node.isOnline, isVerified: node.isVerified)
                                    VStack(alignment: .leading) {
                                        Text(node.displayName)
                                        if !node.profession.isEmpty {
                                            Text(node.profession).font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
                                        }
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(NodiColor.primaryText)
                            }
                            .accessibilityLabel(node.isCluster ? node.displayName : "\(node.displayName), \(node.profession)")
                            .accessibilityHint(node.isCluster ? "Double tap to expand" : "Double tap to view profile")
                        }
                    }
                }
            }
            .navigationTitle("Network (List)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { openProfileId.map(GraphProfileID.init) },
                set: { openProfileId = $0?.id }
            )) { wrapper in
                NavigationStack {
                    ProfileView(userId: wrapper.id, isOwnProfile: false)
                }
            }
        }
    }
}

private struct GraphProfileID: Identifiable {
    let id: String
}

private struct GraphFiltersSheet: View {
    @Binding var activeFilters: Set<ConnectionType>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ConnectionType.allCases) { type in
                Button {
                    if activeFilters.contains(type) {
                        activeFilters.remove(type)
                    } else {
                        activeFilters.insert(type)
                    }
                } label: {
                    HStack {
                        Label(type.label, systemImage: type.icon)
                        Spacer()
                        if activeFilters.contains(type) {
                            Image(systemName: "checkmark").foregroundStyle(NodiColor.accent)
                        }
                    }
                    .foregroundStyle(NodiColor.primaryText)
                }
            }
            .navigationTitle("Filter Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { activeFilters = [] }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
