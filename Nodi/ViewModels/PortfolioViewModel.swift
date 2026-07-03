import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {

    @Published private(set) var publishedProjects: [PortfolioProject] = []
    @Published private(set) var draftProjects: [PortfolioProject] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let ownerId: String
    let isOwnProfile: Bool

    init(ownerId: String, isOwnProfile: Bool) {
        self.ownerId = ownerId
        self.isOwnProfile = isOwnProfile
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isOwnProfile {
                let all = try await ProjectRepository.shared.fetchAllProjects(ownerId: ownerId)
                publishedProjects = all.filter { $0.status == .published }
                draftProjects = all.filter { $0.status == .draft }
            } else {
                publishedProjects = try await ProjectRepository.shared.fetchPublishedProjects(ownerId: ownerId)
                draftProjects = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ project: PortfolioProject) async {
        guard let id = project.id else { return }
        do {
            try await ProjectRepository.shared.delete(projectId: id)
            publishedProjects.removeAll { $0.id == id }
            draftProjects.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
