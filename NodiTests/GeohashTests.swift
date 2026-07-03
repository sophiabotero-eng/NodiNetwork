import XCTest
@testable import Nodi

final class GeohashTests: XCTestCase {

    func test_encode_isDeterministic() {
        let a = Geohash.encode(latitude: 34.0522, longitude: -118.2437, precision: 9)
        let b = Geohash.encode(latitude: 34.0522, longitude: -118.2437, precision: 9)
        XCTAssertEqual(a, b)
    }

    func test_encode_nearbyCoordinatesShareAPrefix() {
        let downtownLA = Geohash.encode(latitude: 34.0522, longitude: -118.2437, precision: 6)
        let hollywood = Geohash.encode(latitude: 34.0928, longitude: -118.3287, precision: 6)
        // Not asserting exact equality (that's flaky near cell boundaries);
        // just that a shorter, coarser prefix matches for two points a few
        // miles apart, which is the property the discovery query relies on.
        let coarseA = String(downtownLA.prefix(3))
        let coarseB = String(hollywood.prefix(3))
        XCTAssertEqual(coarseA, coarseB)
    }

    func test_encode_producesRequestedLength() {
        let hash = Geohash.encode(latitude: 0, longitude: 0, precision: 7)
        XCTAssertEqual(hash.count, 7)
    }

    func test_precisionForRadius_decreasesAsRadiusGrows() {
        XCTAssertGreaterThan(
            Geohash.precision(forRadiusKilometers: 0.1),
            Geohash.precision(forRadiusKilometers: 100)
        )
    }
}
