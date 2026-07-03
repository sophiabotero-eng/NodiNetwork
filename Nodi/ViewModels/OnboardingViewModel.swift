import Foundation
import UIKit
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {

    enum Step: Int, CaseIterable {
        case username
        case identity
        case photo
        case profession
        case links
        case software

        var title: String {
            switch self {
            case .username: return "Claim your handle"
            case .identity: return "What should we call you?"
            case .photo: return "Add a face to the name"
            case .profession: return "What do you make?"
            case .links: return "Where can people find your work?"
            case .software: return "What's in your toolkit?"
            }
        }
    }

    @Published var step: Step = .username

    @Published var username = ""
    @Published var usernameStatus: UsernameStatus = .idle
    @Published var displayName = ""
    @Published var bio = ""

    @Published var profilePhoto: UIImage?
    @Published var coverImage: UIImage?

    @Published var profession = ""
    @Published var location = ""

    @Published var website = ""
    @Published var instagramHandle = ""
    @Published var linkedInHandle = ""
    @Published var behanceHandle = ""

    @Published var availability: AvailabilityStatus = .open
    @Published var softwareInput = ""
    @Published var selectedSoftware: [String] = []

    @Published var isSubmitting = false
    @Published var errorMessage: String?

    static let suggestedSoftware = [
        "Figma", "Photoshop", "Illustrator", "After Effects", "Premiere Pro",
        "Cinema 4D", "Blender", "Procreate", "Final Cut Pro", "InDesign",
        "Lightroom", "DaVinci Resolve", "Sketch", "Rhino", "AutoCAD"
    ]

    enum UsernameStatus: Equatable {
        case idle
        case checking
        case available
        case taken
        case invalid
    }

    private var usernameCheckTask: Task<Void, Never>?

    func onUsernameChanged() {
        usernameCheckTask?.cancel()
        let candidate = username.trimmingCharacters(in: .whitespaces).lowercased()

        guard Self.isValidUsername(candidate) else {
            usernameStatus = candidate.isEmpty ? .idle : .invalid
            return
        }

        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                let available = try await UserRepository.shared.isUsernameAvailable(candidate)
                guard !Task.isCancelled else { return }
                usernameStatus = available ? .available : .taken
            } catch {
                usernameStatus = .idle
            }
        }
    }

    static func isValidUsername(_ value: String) -> Bool {
        let regex = "^[a-z0-9_]{3,20}$"
        return value.range(of: regex, options: .regularExpression) != nil
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

    var canAdvance: Bool {
        switch step {
        case .username: return usernameStatus == .available
        case .identity: return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo: return true
        case .profession: return !profession.trimmingCharacters(in: .whitespaces).isEmpty
        case .links: return true
        case .software: return true
        }
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func submit(session: SessionStore) async -> Bool {
        guard let uid = session.currentUser?.id else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var profilePhotoURL: String?
            var coverImageURL: String?

            if let profilePhoto {
                profilePhotoURL = try await StorageService.shared
                    .uploadImage(profilePhoto, kind: .profilePhoto, ownerId: uid)
                    .absoluteString
            }
            if let coverImage {
                coverImageURL = try await StorageService.shared
                    .uploadImage(coverImage, kind: .coverImage, ownerId: uid)
                    .absoluteString
            }

            try await UserRepository.shared.reserveUsername(username, for: uid, previousUsername: nil)

            var fields: [String: Any] = [
                "displayName": displayName,
                "bio": bio,
                "profession": profession,
                "location": location,
                "website": website,
                "instagramHandle": instagramHandle,
                "linkedInHandle": linkedInHandle,
                "behanceHandle": behanceHandle,
                "availability": availability.rawValue,
                "softwareUsed": selectedSoftware,
                "onboardingComplete": true,
                "searchKeywords": NodiUser.buildSearchKeywords(
                    displayName: displayName,
                    username: username,
                    profession: profession
                )
            ]
            if let profilePhotoURL { fields["profilePhotoURL"] = profilePhotoURL }
            if let coverImageURL { fields["coverImageURL"] = coverImageURL }

            try await UserRepository.shared.updateUser(uid: uid, fields: fields)
            await session.refreshCurrentUser()
            session.completeOnboarding()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
