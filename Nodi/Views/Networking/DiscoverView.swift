import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var mode: Mode = .search

    private enum Mode: String, CaseIterable {
        case search = "Search"
        case nearby = "Nearby"
    }

    var body: some View {
        VStack(spacing: NodiSpacing.sm) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, NodiSpacing.lg)

            if mode == .search {
                searchSection
            } else {
                nearbySection
            }
        }
        .padding(.top, NodiSpacing.sm)
    }

    private var searchSection: some View {
        VStack(spacing: NodiSpacing.sm) {
            HStack {
                NodiTextField(title: "", text: $viewModel.searchQuery, placeholder: "Search by name, username, profession…")
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.onSearchQueryChanged(currentUserId: session.currentUser?.id)
                    }

                Button {
                    viewModel.showingFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle\(viewModel.filters.isEmpty ? "" : ".fill")")
                        .font(.system(size: 22))
                        .foregroundStyle(NodiColor.accent)
                }
            }
            .padding(.horizontal, NodiSpacing.lg)

            if viewModel.isLoading {
                ProgressView().padding(.top, NodiSpacing.xl)
            } else if viewModel.searchResults.isEmpty {
                EmptyStateView(
                    icon: "sparkle.magnifyingglass",
                    title: "Find creatives",
                    message: "Search by name or use filters to browse by profession, location, school, company, or software."
                )
            } else {
                List(viewModel.searchResults) { user in
                    NavigationLink(value: user.id ?? "") {
                        DiscoveryUserRow(user: user)
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $viewModel.showingFilters) {
            DiscoveryFiltersSheet(filters: $viewModel.filters) {
                Task { await viewModel.runSearch() }
            }
        }
    }

    private var nearbySection: some View {
        Group {
            if viewModel.isLoadingNearby {
                ProgressView().padding(.top, NodiSpacing.xl)
            } else if viewModel.nearbyUsers.isEmpty {
                EmptyStateView(
                    icon: "location.circle",
                    title: "No one nearby yet",
                    message: "We'll show creatives near you here once location access is on and others are nearby.",
                    actionTitle: "Enable Location"
                ) {
                    Task { await viewModel.loadNearby(currentUserId: session.currentUser?.id) }
                }
            } else {
                List(viewModel.nearbyUsers) { user in
                    NavigationLink(value: user.id ?? "") {
                        DiscoveryUserRow(user: user)
                    }
                }
                .listStyle(.plain)
            }
        }
        .task {
            await viewModel.loadNearby(currentUserId: session.currentUser?.id)
        }
    }
}

private struct DiscoveryUserRow: View {
    let user: NodiUser

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            NodiAvatarView(urlString: user.profilePhotoURL, size: 48, isVerified: user.isVerified)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(NodiFont.headline())
                Text(user.profession.isEmpty ? "@\(user.username)" : "\(user.profession) · @\(user.username)")
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}

private struct DiscoveryFiltersSheet: View {
    @Binding var filters: DiscoveryFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Profession") {
                    TextField("e.g. Motion Designer", text: $filters.profession)
                }
                Section("Location") {
                    TextField("e.g. Los Angeles", text: $filters.location)
                }
                Section("School") {
                    TextField("e.g. RISD", text: $filters.school)
                }
                Section("Company") {
                    TextField("e.g. Studio Nodi", text: $filters.company)
                }
                Section("Software") {
                    TextField("e.g. Figma", text: $filters.software)
                }
                Section("Availability") {
                    Picker("Availability", selection: $filters.availability) {
                        Text("Any").tag(AvailabilityStatus?.none)
                        ForEach(AvailabilityStatus.allCases) { status in
                            Text(status.label).tag(AvailabilityStatus?.some(status))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { filters = DiscoveryFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}
