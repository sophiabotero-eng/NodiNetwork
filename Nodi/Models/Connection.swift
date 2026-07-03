import Foundation
import SwiftUI
import FirebaseFirestoreSwift

enum ConnectionType: String, Codable, CaseIterable, Identifiable {
    case friend
    case collaborator
    case school
    case work
    case mentor
    case client
    case studio
    case event

    var id: String { rawValue }

    var label: String {
        switch self {
        case .friend: return "Friend"
        case .collaborator: return "Collaborator"
        case .school: return "School"
        case .work: return "Work"
        case .mentor: return "Mentor"
        case .client: return "Client"
        case .studio: return "Studio"
        case .event: return "Event"
        }
    }

    var icon: String {
        switch self {
        case .friend: return "person.2"
        case .collaborator: return "paintpalette"
        case .school: return "graduationcap"
        case .work: return "briefcase"
        case .mentor: return "star"
        case .client: return "building.2"
        case .studio: return "square.stack.3d.up"
        case .event: return "calendar"
        }
    }

    /// Used for graph edges in Phase 4.
    var edgeColor: Color {
        switch self {
        case .friend: return NodiColor.edgeFriend
        case .collaborator: return NodiColor.edgeWorkedTogether
        case .school: return NodiColor.edgeSchool
        case .work: return NodiColor.edgeWorkedTogether
        case .mentor: return NodiColor.edgeMentor
        case .client: return NodiColor.edgeClient
        case .studio: return NodiColor.edgeStudio
        case .event: return NodiColor.edgeEvent
        }
    }
}

enum ConnectionStatus: String, Codable {
    case pending
    case accepted
    case declined
}

enum ConnectionSource: String, Codable {
    case nfcTag = "nfc_tag"
    case qrCode = "qr_code"
    case shareLink = "share_link"
    case manualRequest = "manual_request"
}

struct ConnectionParticipantSummary: Codable, Equatable, Hashable {
    var displayName: String
    var username: String
    var photoURL: String?
    var profession: String
    /// Denormalized at connection-creation time. Verification status
    /// changes rarely, so this can go briefly stale between when someone
    /// is verified and when they next form a new connection — acceptable
    /// for a graph node badge; unlike online status, it's not worth a
    /// live read per node to keep perfectly fresh.
    var isVerified: Bool = false
}

/// Top-level `connections/{id}` collection. `participantIds` always holds
/// exactly two UIDs in sorted order, both so a single `array-contains`
/// query finds "my connections" and so the pair maps to a stable,
/// deterministic document ID (`Connection.documentId(for:)`) that makes a
/// duplicate connection between the same two people structurally
/// impossible rather than something rules have to police.
struct Connection: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var participantIds: [String]
    var participants: [String: ConnectionParticipantSummary]

    var requestedBy: String
    var type: ConnectionType
    var status: ConnectionStatus
    var source: ConnectionSource

    var createdAt: Date
    var respondedAt: Date?

    static func documentId(for uidA: String, _ uidB: String) -> String {
        [uidA, uidB].sorted().joined(separator: "_")
    }

    func other(than uid: String) -> ConnectionParticipantSummary? {
        guard let otherId = participantIds.first(where: { $0 != uid }) else { return nil }
        return participants[otherId]
    }

    func otherId(than uid: String) -> String? {
        participantIds.first(where: { $0 != uid })
    }
}

/// Top-level `follows/{followerId_followingId}` collection — a one-way
/// relationship, separate from `connections` (which are mutual/typed).
struct Follow: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var followerId: String
    var followingId: String
    var createdAt: Date

    static func documentId(follower: String, following: String) -> String {
        "\(follower)_\(following)"
    }
}
