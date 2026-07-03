import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var projects: [PortfolioProject] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var totalProjectViews: Int { projects.reduce(0) { $0 + $1.viewCount } }

    func load(ownerId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let all = try await ProjectRepository.shared.fetchAllProjects(ownerId: ownerId)
            projects = all.sorted { $0.viewCount > $1.viewCount }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
