import Foundation
import FirebaseFirestoreSwift

/// Canonical Firestore document shape for `users/{uid}`.
struct NodiUser: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?

    var username: String
    var displayName: String
    var email: String
    var bio: String
    var profession: String
    var location: String
    var website: String
    var instagramHandle: String
    var linkedInHandle: String
    var behanceHandle: String

    /// Added in Phase 3 to support Discovery's "school"/"company" filters,
    /// which the spec calls for but Phase 1's onboarding never collects.
    /// Optional and editable from Edit Profile rather than onboarding, so
    /// they don't force new users through more steps to get in the door.
    var school: String
    var currentCompany: String

    var profilePhotoURL: String?
    var coverImageURL: String?

    /// Only meaningful when `accountType` is `.studio`/`.team` — the
    /// individual Nodi accounts that make up the studio/team, shown as a
    /// member grid on the profile. Denormalized names avoid an N-read
    /// fan-out just to render the member list.
    var teamMemberIds: [String]
    var teamMemberNames: [String]

    var softwareUsed: [String]
    var availability: AvailabilityStatus

    var isVerified: Bool
    var accountType: AccountType

    var followerCount: Int
    var followingCount: Int
    var connectionCount: Int
    var projectCount: Int
    var profileViewCount: Int

    var authProviders: [AuthProvider]
    var onboardingComplete: Bool
    var fcmTokens: [String]

    var createdAt: Date
    var updatedAt: Date
    var lastActiveAt: Date

    /// Geohash + raw coordinates for nearby-creatives discovery (Phase 3).
    var geohash: String?
    var latitude: Double?
    var longitude: Double?

    var searchKeywords: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case email
        case bio
        case profession
        case location
        case website
        case instagramHandle
        case linkedInHandle
        case behanceHandle
        case school
        case currentCompany
        case profilePhotoURL
        case coverImageURL
        case teamMemberIds
        case teamMemberNames
        case softwareUsed
        case availability
        case isVerified
        case accountType
        case followerCount
        case followingCount
        case connectionCount
        case projectCount
        case profileViewCount
        case authProviders
        case onboardingComplete
        case fcmTokens
        case createdAt
        case updatedAt
        case lastActiveAt
        case geohash
        case latitude
        case longitude
        case searchKeywords
    }

    static func draft(uid: String, email: String, displayName: String, providers: [AuthProvider]) -> NodiUser {
        let now = Date()
        return NodiUser(
            id: uid,
            username: "",
            displayName: displayName,
            email: email,
            bio: "",
            profession: "",
            location: "",
            website: "",
            instagramHandle: "",
            linkedInHandle: "",
            behanceHandle: "",
            school: "",
            currentCompany: "",
            profilePhotoURL: nil,
            coverImageURL: nil,
            teamMemberIds: [],
            teamMemberNames: [],
            softwareUsed: [],
            availability: .open,
            isVerified: false,
            accountType: .individual,
            followerCount: 0,
            followingCount: 0,
            connectionCount: 0,
            projectCount: 0,
            profileViewCount: 0,
            authProviders: providers,
            onboardingComplete: false,
            fcmTokens: [],
            createdAt: now,
            updatedAt: now,
            lastActiveAt: now,
            geohash: nil,
            latitude: nil,
            longitude: nil,
            searchKeywords: NodiUser.buildSearchKeywords(displayName: displayName, username: "", profession: "")
        )
    }

    static func buildSearchKeywords(displayName: String, username: String, profession: String) -> [String] {
        let raw = [displayName, username, profession]
            .joined(separator: " ")
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        return Array(Set(raw)).filter { !$0.isEmpty }
    }
}

enum AuthProvider: String, Codable, Hashable {
    case apple
    case google
    case email
}

enum AvailabilityStatus: String, Codable, CaseIterable, Identifiable {
    case open = "open_to_work"
    case selective = "selective"
    case unavailable = "unavailable"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open to work"
        case .selective: return "Selectively available"
        case .unavailable: return "Not available"
        }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case individual
    case studio
    case team

    var id: String { rawValue }
}
