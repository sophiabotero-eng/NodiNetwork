import Foundation
import UIKit

@MainActor
final class EditProfileViewModel: ObservableObject {

    @Published var username: String
    @Published var usernameStatus: OnboardingViewModel.UsernameStatus = .idle
    @Published var displayName: String
    @Published var bio: String
    @Published var profession: String
    @Published var location: String
    @Published var website: String
    @Published var instagramHandle: String
    @Published var linkedInHandle: String
    @Published var behanceHandle: String
    @Published var school: String
    @Published var currentCompany: String
    @Published var availability: AvailabilityStatus
    @Published var accountType: AccountType
    @Published var selectedSoftware: [String]
    @Published var softwareInput = ""

    @Published var teamMembers: [TeamMemberRef]
    @Published var teamMemberSearchQuery = ""
    @Published var teamMemberResults: [NodiUser] = []

    struct TeamMemberRef: Identifiable, Equatable {
        let id: String
        let name: String
    }

    @Published var profilePhoto: UIImage?
    @Published var coverImage: UIImage?
    @Published var existingProfilePhotoURL: String?
    @Published var existingCoverImageURL: String?

    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    private let originalUsername: String
    private var usernameCheckTask: Task<Void, Never>?

    init(user: NodiUser) {
        self.username = user.username
        self.originalUsername = user.username
        self.displayName = user.displayName
        self.bio = user.bio
        self.profession = user.profession
        self.location = user.location
        self.website = user.website
        self.instagramHandle = user.instagramHandle
        self.linkedInHandle = user.linkedInHandle
        self.behanceHandle = user.behanceHandle
        self.school = user.school
        self.currentCompany = user.currentCompany
        self.availability = user.availability
        self.accountType = user.accountType
        self.selectedSoftware = user.softwareUsed
        self.teamMembers = zip(user.teamMemberIds, user.teamMemberNames).map { TeamMemberRef(id: $0, name: $1) }
        self.existingProfilePhotoURL = user.profilePhotoURL
        self.existingCoverImageURL = user.coverImageURL
        self.usernameStatus = .available
    }

    func onUsernameChanged() {
        usernameCheckTask?.cancel()
        let candidate = username.trimmingCharacters(in: .whitespaces).lowercased()

        if candidate == originalUsername.lowercased() {
            usernameStatus = .available
            return
        }
        guard OnboardingViewModel.isValidUsername(candidate) else {
            usernameStatus = candidate.isEmpty ? .idle : .invalid
            return
        }
        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let available = (try? await UserRepository.shared.isUsernameAvailable(candidate)) ?? false
            guard !Task.isCancelled else { return }
            usernameStatus = available ? .available : .taken
        }
    }

    func addSoftware(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedSoftware.contains(trimmed) else { return }
        selectedSoftware.append(trimmed)
        softwareInput = ""
    }

    func removeSoftware(_ name: String) {
        selectedSoftware.removeAll { $0 == name }
    }

    func searchTeamMembers() async {
        guard !teamMemberSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            teamMemberResults = []
            return
        }
        teamMemberResults = (try? await UserRepository.shared.searchUsers(matching: teamMemberSearchQuery)) ?? []
    }

    func addTeamMember(_ user: NodiUser) {
        guard let id = user.id, !teamMembers.contains(where: { $0.id == id }) else { return }
        teamMembers.append(TeamMemberRef(id: id, name: user.displayName))
        teamMemberSearchQuery = ""
        teamMemberResults = []
    }

    func removeTeamMember(_ member: TeamMemberRef) {
        teamMembers.removeAll { $0.id == member.id }
    }

    var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && usernameStatus == .available
    }

    func save(session: SessionStore) async {
        guard let uid = session.currentUser?.id, canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            if username.lowercased() != originalUsername.lowercased() {
                try await UserRepository.shared.reserveUsername(username, for: uid, previousUsername: originalUsername)
            }

            var fields: [String: Any] = [
                "displayName": displayName,
                "bio": bio,
                "profession": profession,
                "location": location,
                "website": website,
                "instagramHandle": instagramHandle,
                "linkedInHandle": linkedInHandle,
                "behanceHandle": behanceHandle,
                "school": school,
                "currentCompany": currentCompany,
                "availability": availability.rawValue,
                "accountType": accountType.rawValue,
                "softwareUsed": selectedSoftware,
                "teamMemberIds": teamMembers.map(\.id),
                "teamMemberNames": teamMembers.map(\.name),
                "searchKeywords": NodiUser.buildSearchKeywords(
                    displayName: displayName,
                    username: username,
                    profession: profession
                )
            ]

            if let profilePhoto {
                let url = try await StorageService.shared.uploadImage(profilePhoto, kind: .profilePhoto, ownerId: uid)
                fields["profilePhotoURL"] = url.absoluteString
            }
            if let coverImage {
                let url = try await StorageService.shared.uploadImage(coverImage, kind: .coverImage, ownerId: uid)
                fields["coverImageURL"] = url.absoluteString
            }

            try await UserRepository.shared.updateUser(uid: uid, fields: fields)
            await session.refreshCurrentUser()
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
