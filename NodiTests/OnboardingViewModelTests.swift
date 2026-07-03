import XCTest
@testable import Nodi

final class OnboardingViewModelTests: XCTestCase {

    func test_usernameValidation_acceptsLowercaseAlphanumericAndUnderscore() {
        XCTAssertTrue(OnboardingViewModel.isValidUsername("ada_lovelace1"))
        XCTAssertTrue(OnboardingViewModel.isValidUsername("abc"))
    }

    func test_usernameValidation_rejectsTooShort() {
        XCTAssertFalse(OnboardingViewModel.isValidUsername("ab"))
    }

    func test_usernameValidation_rejectsUppercaseAndSymbols() {
        XCTAssertFalse(OnboardingViewModel.isValidUsername("Ada.Lovelace"))
        XCTAssertFalse(OnboardingViewModel.isValidUsername("ada lovelace"))
    }

    func test_buildSearchKeywords_dedupesAndLowercases() {
        let keywords = NodiUser.buildSearchKeywords(displayName: "Ada Lovelace", username: "ada", profession: "Engineer")
        XCTAssertTrue(keywords.contains("ada"))
        XCTAssertTrue(keywords.contains("lovelace"))
        XCTAssertTrue(keywords.contains("engineer"))
        XCTAssertEqual(keywords.count, Set(keywords).count)
    }
}
