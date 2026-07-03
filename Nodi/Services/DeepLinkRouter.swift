import Foundation

/// Routes have this shape:
///   nodi://profile/{username}
///   nodi://connect/{connectToken}
///   nodi://project/{userId}/{projectId}
///   nodi://event/{eventId}
/// and the https://nodi.app universal-link equivalents (handled the same
/// way once Associated Domains + an apple-app-site-association file are
/// live — see README → "Deep Linking").
enum NodiDeepLink: Equatable {
    case profile(username: String)
    case connect(token: String)
    case project(userId: String, projectId: String)
    case event(eventId: String)
    case graph(username: String)

    init?(url: URL) {
        let host: String?
        let pathComponents: [String]

        if url.scheme == "nodi" {
            host = url.host
            pathComponents = url.pathComponents.filter { $0 != "/" }
        } else if url.scheme == "https", url.host == "nodi.app" {
            let parts = url.pathComponents.filter { $0 != "/" }
            host = parts.first
            pathComponents = Array(parts.dropFirst())
        } else {
            return nil
        }

        switch host {
        case "profile":
            guard let username = pathComponents.first else { return nil }
            self = .profile(username: username)
        case "graph":
            guard let username = pathComponents.first else { return nil }
            self = .graph(username: username)
        case "connect":
            guard let token = pathComponents.first else { return nil }
            self = .connect(token: token)
        case "project":
            guard pathComponents.count >= 2 else { return nil }
            self = .project(userId: pathComponents[0], projectId: pathComponents[1])
        case "event":
            guard let eventId = pathComponents.first else { return nil }
            self = .event(eventId: eventId)
        default:
            return nil
        }
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

    @Published var pendingLink: NodiDeepLink?

    private init() {}

    func handle(url: URL, session: SessionStore) {
        guard let link = NodiDeepLink(url: url) else { return }
        pendingLink = link
    }

    func consumePendingLink() -> NodiDeepLink? {
        defer { pendingLink = nil }
        return pendingLink
    }
}
