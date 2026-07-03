import XCTest
@testable import Nodi

final class GraphModelsTests: XCTestCase {

    func test_zoomLevel_ordering() {
        XCTAssertLessThan(GraphZoomLevel.singleProfile, .directConnections)
        XCTAssertLessThan(GraphZoomLevel.directConnections, .friendsOfFriends)
        XCTAssertLessThan(GraphZoomLevel.friendsOfFriends, .fullEcosystem)
    }

    func test_zoomLevel_maxRealDepthIncreasesMonotonically() {
        let depths = GraphZoomLevel.allCases.sorted().map(\.maxRealDepth)
        XCTAssertEqual(depths, depths.sorted())
    }

    func test_graphNode_clusterRadiusGrowsWithCount() {
        let small = GraphNode(id: "a", displayName: "", username: "", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 1, kind: .cluster(count: 2), parentId: "root", position: .zero)
        let large = GraphNode(id: "b", displayName: "", username: "", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 1, kind: .cluster(count: 500), parentId: "root", position: .zero)
        XCTAssertLessThan(small.baseRadius, large.baseRadius)
    }

    func test_graphNode_centerIsLargestRealNode() {
        let center = GraphNode(id: "center", displayName: "", username: "", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 0, kind: .real, parentId: nil, position: .zero)
        let direct = GraphNode(id: "direct", displayName: "", username: "", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 1, kind: .real, parentId: "center", position: .zero)
        XCTAssertGreaterThan(center.baseRadius, direct.baseRadius)
    }

    func test_graphNode_equalityIsIdentityBased() {
        var a = GraphNode(id: "x", displayName: "Ada", username: "ada", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 0, kind: .real, parentId: nil, position: .zero)
        let b = GraphNode(id: "x", displayName: "Different Name", username: "ada", profession: "", photoURL: nil, isVerified: false, isOnline: false, depth: 0, kind: .real, parentId: nil, position: CGPoint(x: 10, y: 10))
        XCTAssertEqual(a, b)
        a.position = CGPoint(x: 999, y: 999)
        XCTAssertEqual(a, b) // still equal — GraphNode equality is id-only, positions mutate every simulation tick
    }
}
