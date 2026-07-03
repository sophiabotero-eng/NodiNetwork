import Foundation
import CoreGraphics

/// The four zoom levels called for in the spec. These are discrete
/// states (not a continuous zoom value) — crossing a pinch threshold
/// steps between them, loading progressively more of the network. A
/// separate continuous camera scale/offset (`GraphCamera`) still lets you
/// pan and zoom smoothly *within* whichever level is active.
enum GraphZoomLevel: Int, CaseIterable, Comparable {
    case singleProfile = 1
    case directConnections = 2
    case friendsOfFriends = 3
    case fullEcosystem = 4

    static func < (lhs: GraphZoomLevel, rhs: GraphZoomLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .singleProfile: return "Profile"
        case .directConnections: return "Connections"
        case .friendsOfFriends: return "Extended Network"
        case .fullEcosystem: return "Full Ecosystem"
        }
    }

    /// How many hops from the center user this level loads real (not
    /// clustered) node data out to.
    var maxRealDepth: Int {
        switch self {
        case .singleProfile: return 0
        case .directConnections: return 1
        case .friendsOfFriends: return 2
        case .fullEcosystem: return 3
        }
    }
}

enum GraphNodeKind: Equatable {
    case real
    /// A stand-in for a frontier of nodes we haven't (or won't, at this
    /// zoom level) load individually — see GraphViewModel's node cap.
    /// Tapping one expands it into its real members.
    case cluster(count: Int)
}

/// A node in the rendered graph. Value type by design — `GraphViewModel`
/// owns one `[GraphNode]` array that's replaced wholesale each simulation
/// tick, which is simpler and fast enough at the node counts this view
/// actually keeps resident (see GraphViewModel's clustering cap) than
/// giving each node its own `ObservableObject`.
struct GraphNode: Identifiable, Equatable {
    let id: String
    var displayName: String
    var username: String
    var profession: String
    var photoURL: String?
    var isVerified: Bool
    var isOnline: Bool
    var depth: Int
    var kind: GraphNodeKind
    var parentId: String?

    var position: CGPoint
    var velocity: CGVector = .zero

    /// True in the brief window right after a cluster expands, so the
    /// view can pop the new nodes in instead of having them appear at
    /// full size instantly.
    var isNewlyExpanded: Bool = false

    var isCluster: Bool {
        if case .cluster = kind { return true }
        return false
    }

    var baseRadius: CGFloat {
        switch kind {
        case .real:
            switch depth {
            case 0: return 34
            case 1: return 24
            case 2: return 18
            default: return 14
            }
        case .cluster(let count):
            return min(30, 14 + CGFloat(count).squareRoot() * 2)
        }
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool { lhs.id == rhs.id }
}

struct GraphEdge: Identifiable, Equatable {
    let id: String
    let sourceId: String
    let targetId: String
    let type: ConnectionType
    var isMutualGlow: Bool
}

/// Continuous pan/zoom state within a `GraphZoomLevel`, driven by
/// `MagnificationGesture`/`DragGesture` in `GraphCanvasView`.
struct GraphCamera: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
}
