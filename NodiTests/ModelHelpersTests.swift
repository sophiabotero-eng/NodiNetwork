import XCTest
@testable import Nodi

final class ModelHelpersTests: XCTestCase {

    func test_connection_documentId_isOrderIndependent() {
        XCTAssertEqual(Connection.documentId(for: "a", "b"), Connection.documentId(for: "b", "a"))
    }

    func test_follow_documentId_isOrderDependent() {
        // Unlike Connection, a follow is directional — "a follows b" and
        // "b follows a" must be distinct documents.
        XCTAssertNotEqual(Follow.documentId(follower: "a", following: "b"), Follow.documentId(follower: "b", following: "a"))
    }

    func test_conversation_documentId_isOrderIndependent() {
        XCTAssertEqual(Conversation.documentId(for: "a", "b"), Conversation.documentId(for: "b", "a"))
    }

    func test_connection_other_returnsCounterparty() {
        let connection = Connection(
            id: "a_b",
            participantIds: ["a", "b"],
            participants: [
                "a": ConnectionParticipantSummary(displayName: "Ada", username: "ada", photoURL: nil, profession: "", isVerified: false),
                "b": ConnectionParticipantSummary(displayName: "Bea", username: "bea", photoURL: nil, profession: "", isVerified: false)
            ],
            requestedBy: "a",
            type: .friend,
            status: .accepted,
            source: .qrCode,
            createdAt: Date(),
            respondedAt: Date()
        )
        XCTAssertEqual(connection.other(than: "a")?.displayName, "Bea")
        XCTAssertEqual(connection.otherId(than: "b"), "a")
    }

    func test_event_isUpcoming() {
        let future = NodiEvent(
            title: "Meetup", eventDescription: "", coverImageURL: nil,
            hostId: "h", hostDisplayName: "Host", hostPhotoURL: nil,
            location: "", geohash: nil, latitude: nil, longitude: nil,
            startsAt: Date().addingTimeInterval(3600), endsAt: nil,
            attendeeIds: ["h"], createdAt: Date()
        )
        let past = NodiEvent(
            title: "Past", eventDescription: "", coverImageURL: nil,
            hostId: "h", hostDisplayName: "Host", hostPhotoURL: nil,
            location: "", geohash: nil, latitude: nil, longitude: nil,
            startsAt: Date().addingTimeInterval(-3600), endsAt: nil,
            attendeeIds: ["h"], createdAt: Date()
        )
        XCTAssertTrue(future.isUpcoming)
        XCTAssertFalse(past.isUpcoming)
    }

    func test_project_buildSearchKeywords_dedupesLowercased() {
        let keywords = PortfolioProject.buildSearchKeywords(title: "Brand Identity", tags: ["Branding", "logo"], software: ["Illustrator"])
        XCTAssertTrue(keywords.contains("brand"))
        XCTAssertTrue(keywords.contains("branding"))
        XCTAssertTrue(keywords.contains("illustrator"))
        XCTAssertEqual(keywords.count, Set(keywords).count)
    }

    func test_discoveryFilters_isEmpty() {
        var filters = DiscoveryFilters()
        XCTAssertTrue(filters.isEmpty)
        filters.profession = "Designer"
        XCTAssertFalse(filters.isEmpty)
    }
}
