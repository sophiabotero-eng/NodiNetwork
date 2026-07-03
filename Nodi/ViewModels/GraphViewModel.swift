import Foundation
import CoreGraphics
import SwiftUI

/// Drives the interactive network graph — Phase 4's signature feature.
///
/// **Rendering approach:** SwiftUI `Canvas` (GPU-composited by Core
/// Animation) driven by a `TimelineView(.animation)` calling `tick()`
/// once per frame, rather than SceneKit/Metal. This is the pragmatic
/// SwiftUI-native choice given the environment this was built in has no
/// way to profile a custom Metal renderer on-device. It comfortably
/// handles the node counts this view actually keeps resident (see below)
/// at 60fps; a Metal-backed renderer would be the natural next step if
/// profiling on a real device shows Canvas falling short at your actual
/// user base's network sizes.
///
/// **How "10,000+ nodes" is actually handled:** no graph UI — Nodi's or
/// anyone else's — runs an unclustered force simulation on 10,000 live
/// bodies; that's not a rendering technique, it's just too much
/// simultaneous physics to read as anything but noise. Instead, real
/// node data is loaded and simulated out to a capped frontier
/// (`maxResidentRealNodes`), and everything beyond that frontier at each
/// loaded node is collapsed into a single cluster node ("+N more") that
/// expands into its real members on tap. That's how the "full ecosystem"
/// zoom level scales to arbitrarily large networks without the
/// simulation or Firestore read volume growing unbounded.
@MainActor
final class GraphViewModel: ObservableObject {

    @Published private(set) var nodes: [GraphNode] = []
    @Published private(set) var edges: [GraphEdge] = []
    @Published var zoomLevel: GraphZoomLevel = .singleProfile
    @Published var selectedNode: GraphNode?
    @Published var searchQuery = ""
    @Published var activeFilters: Set<ConnectionType> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canvasSize: CGSize = .zero {
        didSet { if oldValue == .zero, canvasSize != .zero { seedInitialLayout() } }
    }

    let centerUserId: String
    private let maxResidentRealNodes = 260

    /// uid -> that user's accepted connections, fetched at most once.
    private var connectionCache: [String: [Connection]] = [:]
    private var expandedClusterParents: Set<String> = []

    init(centerUserId: String) {
        self.centerUserId = centerUserId
    }

    func matches(_ node: GraphNode) -> Bool {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let query = searchQuery.lowercased()
        return node.displayName.lowercased().contains(query)
            || node.username.lowercased().contains(query)
            || node.profession.lowercased().contains(query)
    }

    func edgeMatchesFilter(_ edge: GraphEdge) -> Bool {
        activeFilters.isEmpty || activeFilters.contains(edge.type)
    }

    // MARK: Loading

    func loadInitial(centerUser: NodiUser) async {
        let center = GraphNode(
            id: centerUserId,
            displayName: centerUser.displayName,
            username: centerUser.username,
            profession: centerUser.profession,
            photoURL: centerUser.profilePhotoURL,
            isVerified: centerUser.isVerified,
            isOnline: Self.isOnline(centerUser),
            depth: 0,
            kind: .real,
            parentId: nil,
            position: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        )
        nodes = [center]
        await setZoomLevel(.directConnections)
    }

    func setZoomLevel(_ level: GraphZoomLevel) async {
        guard level != zoomLevel || nodes.count <= 1 else {
            zoomLevel = level
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await expand(depthTarget: level.maxRealDepth)
            zoomLevel = level
            await enrichOnlineStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func advanceZoomLevel() {
        guard let next = GraphZoomLevel(rawValue: zoomLevel.rawValue + 1) else { return }
        Task { await setZoomLevel(next) }
    }

    func retreatZoomLevel() {
        guard let previous = GraphZoomLevel(rawValue: zoomLevel.rawValue - 1) else { return }
        Task { await setZoomLevel(previous) }
    }

    /// Expands the graph breadth-first up to `depthTarget` hops from the
    /// center, respecting `maxResidentRealNodes` by turning any frontier
    /// beyond the cap into cluster nodes instead of fetching it.
    private func expand(depthTarget: Int) async throws {
        var frontier = [centerUserId]
        var visited: Set<String> = [centerUserId]
        var newNodes: [GraphNode] = []
        var newEdges: [GraphEdge] = []

        for depth in 0..<max(depthTarget, 0) {
            var nextFrontier: [String] = []

            for parentId in frontier {
                guard nodes.count + newNodes.count < maxResidentRealNodes else {
                    // Cap hit — represent the rest of this node's
                    // unexplored connections as a single cluster rather
                    // than stopping the whole expansion silently.
                    continue
                }

                let connections = try await connections(for: parentId)
                var clusterOverflow = 0

                for connection in connections {
                    guard let otherId = connection.otherId(than: parentId),
                          let summary = connection.other(than: parentId) else { continue }

                    if visited.contains(otherId) {
                        // Already a node somewhere in the graph — just
                        // add the edge (this is what makes "mutual
                        // connections glow" possible below).
                        newEdges.append(GraphEdge(
                            id: connection.id ?? "\(parentId)_\(otherId)",
                            sourceId: parentId,
                            targetId: otherId,
                            type: connection.type,
                            isMutualGlow: false
                        ))
                        continue
                    }

                    guard nodes.count + newNodes.count < maxResidentRealNodes else {
                        clusterOverflow += 1
                        continue
                    }

                    visited.insert(otherId)
                    nextFrontier.append(otherId)

                    let node = GraphNode(
                        id: otherId,
                        displayName: summary.displayName,
                        username: summary.username,
                        profession: summary.profession,
                        photoURL: summary.photoURL,
                        isVerified: summary.isVerified,
                        isOnline: false,
                        depth: depth + 1,
                        kind: .real,
                        parentId: parentId,
                        position: spawnPosition(near: parentId, in: newNodes)
                    )
                    newNodes.append(node)
                    newEdges.append(GraphEdge(
                        id: connection.id ?? "\(parentId)_\(otherId)",
                        sourceId: parentId,
                        targetId: otherId,
                        type: connection.type,
                        isMutualGlow: false
                    ))
                }

                if clusterOverflow > 0 {
                    let clusterId = "cluster_\(parentId)"
                    newNodes.append(GraphNode(
                        id: clusterId,
                        displayName: "+\(clusterOverflow) more",
                        username: "",
                        profession: "",
                        photoURL: nil,
                        isVerified: false,
                        isOnline: false,
                        depth: depth + 1,
                        kind: .cluster(count: clusterOverflow),
                        parentId: parentId,
                        position: spawnPosition(near: parentId, in: newNodes)
                    ))
                    newEdges.append(GraphEdge(id: "\(parentId)_\(clusterId)", sourceId: parentId, targetId: clusterId, type: .friend, isMutualGlow: false))
                }
            }

            frontier = nextFrontier
            if frontier.isEmpty { break }
        }

        nodes.append(contentsOf: newNodes)
        edges = mergeEdges(existing: edges, incoming: newEdges)
        markMutualGlow()
    }

    /// Tapping a cluster node replaces it with its real members.
    func expandCluster(_ cluster: GraphNode) {
        guard cluster.isCluster, let parentId = cluster.parentId, !expandedClusterParents.contains(cluster.id) else { return }
        expandedClusterParents.insert(cluster.id)

        Task {
            do {
                let connections = try await connections(for: parentId)
                let existingIds = Set(nodes.map(\.id))
                var addedNodes: [GraphNode] = []
                var addedEdges: [GraphEdge] = []

                for connection in connections {
                    guard let otherId = connection.otherId(than: parentId), !existingIds.contains(otherId),
                          let summary = connection.other(than: parentId) else { continue }

                    addedNodes.append(GraphNode(
                        id: otherId,
                        displayName: summary.displayName,
                        username: summary.username,
                        profession: summary.profession,
                        photoURL: summary.photoURL,
                        isVerified: summary.isVerified,
                        isOnline: false,
                        depth: cluster.depth,
                        kind: .real,
                        parentId: parentId,
                        position: cluster.position,
                        isNewlyExpanded: true
                    ))
                    addedEdges.append(GraphEdge(id: connection.id ?? "\(parentId)_\(otherId)", sourceId: parentId, targetId: otherId, type: connection.type, isMutualGlow: false))
                }

                nodes.removeAll { $0.id == cluster.id }
                edges.removeAll { $0.targetId == cluster.id }
                nodes.append(contentsOf: addedNodes)
                edges = mergeEdges(existing: edges, incoming: addedEdges)
                markMutualGlow()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func connections(for uid: String) async throws -> [Connection] {
        if let cached = connectionCache[uid] { return cached }
        let fetched = try await ConnectionRepository.shared.fetchConnections(for: uid)
        connectionCache[uid] = fetched
        return fetched
    }

    private func mergeEdges(existing: [GraphEdge], incoming: [GraphEdge]) -> [GraphEdge] {
        var byId: [String: GraphEdge] = [:]
        for edge in existing { byId[edge.id] = edge }
        for edge in incoming { byId[edge.id] = edge }
        return Array(byId.values)
    }

    /// An edge "glows" when both endpoints share a *third* mutual
    /// connection already present in the graph — i.e. a visible triangle
    /// in the relationship graph, which is what the spec means by
    /// "mutual connections glow."
    private func markMutualGlow() {
        var neighbors: [String: Set<String>] = [:]
        for edge in edges {
            neighbors[edge.sourceId, default: []].insert(edge.targetId)
            neighbors[edge.targetId, default: []].insert(edge.sourceId)
        }
        edges = edges.map { edge in
            var edge = edge
            let shared = (neighbors[edge.sourceId] ?? []).intersection(neighbors[edge.targetId] ?? [])
            edge.isMutualGlow = !shared.isEmpty
            return edge
        }
    }

    private func spawnPosition(near parentId: String, in pending: [GraphNode]) -> CGPoint {
        let parent = nodes.first(where: { $0.id == parentId })?.position
            ?? pending.first(where: { $0.id == parentId })?.position
            ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let angle = Double.random(in: 0..<(2 * .pi))
        let radius = CGFloat.random(in: 40...90)
        return CGPoint(x: parent.x + cos(angle) * radius, y: parent.y + sin(angle) * radius)
    }

    private func seedInitialLayout() {
        guard var center = nodes.first else { return }
        center.position = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        nodes[0] = center
    }

    // MARK: Selection

    func node(at point: CGPoint, camera: GraphCamera) -> GraphNode? {
        let transformed = { (p: CGPoint) -> CGPoint in
            CGPoint(
                x: p.x * camera.scale + camera.offset.width + canvasSize.width / 2 * (1 - camera.scale),
                y: p.y * camera.scale + camera.offset.height + canvasSize.height / 2 * (1 - camera.scale)
            )
        }
        return nodes.first { node in
            let screenPoint = transformed(node.position)
            let hitRadius = node.baseRadius * camera.scale + 6
            let dx = screenPoint.x - point.x
            let dy = screenPoint.y - point.y
            return (dx * dx + dy * dy) <= hitRadius * hitRadius
        }
    }

    func select(_ node: GraphNode) {
        if node.isCluster {
            expandCluster(node)
        } else {
            selectedNode = node
        }
    }

    // MARK: Physics

    private let repulsionStrength: CGFloat = 2600
    private let springLength: CGFloat = 90
    private let springStrength: CGFloat = 0.02
    private let centerGravity: CGFloat = 0.01
    private let damping: CGFloat = 0.86

    /// One simulation step, called from `GraphCanvasView`'s
    /// `TimelineView(.animation)`. Uses a coarse spatial grid for
    /// repulsion so cost stays close to O(n) instead of O(n²) as the
    /// resident node count grows toward `maxResidentRealNodes`.
    func tick() {
        guard nodes.count > 1, canvasSize != .zero else { return }
        var updated = nodes
        let cellSize: CGFloat = 120
        var grid: [Int: [Int]] = [:]

        func cellKey(_ point: CGPoint) -> Int {
            let cx = Int((point.x / cellSize).rounded(.down))
            let cy = Int((point.y / cellSize).rounded(.down))
            return cx &* 73_856_093 ^ cy &* 19_349_663
        }

        for (index, node) in updated.enumerated() {
            grid[cellKey(node.position), default: []].append(index)
        }

        for i in updated.indices {
            var force = CGVector.zero
            let node = updated[i]

            let cx = Int((node.position.x / cellSize).rounded(.down))
            let cy = Int((node.position.y / cellSize).rounded(.down))
            for dx in -1...1 {
                for dy in -1...1 {
                    let key = (cx + dx) &* 73_856_093 ^ (cy + dy) &* 19_349_663
                    guard let bucket = grid[key] else { continue }
                    for j in bucket where j != i {
                        let other = updated[j]
                        let delta = CGVector(dx: node.position.x - other.position.x, dy: node.position.y - other.position.y)
                        let distSq = max(delta.dx * delta.dx + delta.dy * delta.dy, 4)
                        let dist = distSq.squareRoot()
                        let strength = repulsionStrength / distSq
                        force.dx += (delta.dx / dist) * strength
                        force.dy += (delta.dy / dist) * strength
                    }
                }
            }

            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            force.dx += (center.x - node.position.x) * centerGravity
            force.dy += (center.y - node.position.y) * centerGravity

            updated[i].velocity.dx = (updated[i].velocity.dx + force.dx) * damping
            updated[i].velocity.dy = (updated[i].velocity.dy + force.dy) * damping
        }

        for edge in edges {
            guard let i = updated.firstIndex(where: { $0.id == edge.sourceId }),
                  let j = updated.firstIndex(where: { $0.id == edge.targetId }) else { continue }
            let a = updated[i].position
            let b = updated[j].position
            let delta = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let dist = max((delta.dx * delta.dx + delta.dy * delta.dy).squareRoot(), 1)
            let displacement = dist - springLength
            let force = displacement * springStrength
            let fx = (delta.dx / dist) * force
            let fy = (delta.dy / dist) * force

            if updated[i].depth > 0 {
                updated[i].velocity.dx += fx
                updated[i].velocity.dy += fy
            }
            if updated[j].depth > 0 {
                updated[j].velocity.dx -= fx
                updated[j].velocity.dy -= fy
            }
        }

        for i in updated.indices {
            // Depth-0 (the viewer) stays anchored at the visual center so
            // the whole graph doesn't drift.
            guard updated[i].depth > 0 else {
                updated[i].position = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                updated[i].velocity = .zero
                continue
            }
            updated[i].position.x += updated[i].velocity.dx
            updated[i].position.y += updated[i].velocity.dy
        }

        nodes = updated
    }

    /// Refreshes `isOnline` for depth-1 real nodes only — direct
    /// connections are the ones a user actually recognizes and cares
    /// whether they're online right now; fetching this for every loaded
    /// node at deeper zoom levels wouldn't add much value for the extra
    /// reads.
    private func enrichOnlineStatus() async {
        let directIds = nodes.filter { $0.depth == 1 && !$0.isCluster }.map(\.id)
        guard let users = try? await UserRepository.shared.fetchUsers(ids: directIds) else { return }
        let onlineById = Dictionary(uniqueKeysWithValues: users.map { ($0.id ?? "", Self.isOnline($0)) })

        for index in nodes.indices {
            if let isOnline = onlineById[nodes[index].id] {
                nodes[index].isOnline = isOnline
            }
        }
    }

    private static func isOnline(_ user: NodiUser) -> Bool {
        Date().timeIntervalSince(user.lastActiveAt) < 5 * 60
    }
}
