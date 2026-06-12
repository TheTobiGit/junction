@testable import JunctionApp
import XCTest

// VAL-CROSS-009: Settings forward-compat across all milestones.
// Legacy settings.json lacking favoriteTargetKey, pickerFrame, trackerOverrides, toursCompleted
// decodes successfully; all four default to nil/empty; re-encoding then decoding preserves defaults.
final class SettingsForwardCompatTests: XCTestCase {

    private let legacyJSON = """
    {
        "cleanURLsBeforeOpening": true,
        "expandShortenedURLs": true,
        "clipboardWatcherEnabled": false,
        "hiddenTargetKeys": [],
        "targetOrder": ["app:com.apple.Safari"],
        "hasCompletedOnboarding": true,
        "historyEnabled": true
    }
    """.data(using: .utf8)!

    func test_legacyJSON_missingAllFourNewFields_decodesSuccessfully_VAL_CROSS_009() throws {
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: legacyJSON)

        XCTAssertNil(decoded.favoriteTargetKey, "favoriteTargetKey must default to nil")
        XCTAssertNil(decoded.pickerFrame, "pickerFrame must default to nil")
        XCTAssertTrue(decoded.trackerOverrides.additions.isEmpty,
                      "trackerOverrides.additions must default to empty")
        XCTAssertTrue(decoded.trackerOverrides.disabled.isEmpty,
                      "trackerOverrides.disabled must default to empty")
        XCTAssertTrue(decoded.toursCompleted.isEmpty,
                      "toursCompleted must default to empty dict")
    }

    func test_legacyJSON_roundTripPreservesDefaults_VAL_CROSS_009() throws {
        let first = try JSONDecoder().decode(JunctionSettings.self, from: legacyJSON)

        let reencoded = try JSONEncoder().encode(first)
        let second = try JSONDecoder().decode(JunctionSettings.self, from: reencoded)

        XCTAssertNil(second.favoriteTargetKey)
        XCTAssertNil(second.pickerFrame)
        XCTAssertTrue(second.trackerOverrides.additions.isEmpty)
        XCTAssertTrue(second.trackerOverrides.disabled.isEmpty)
        XCTAssertTrue(second.toursCompleted.isEmpty)
        XCTAssertEqual(second.targetOrder, first.targetOrder)
        XCTAssertEqual(second.hasCompletedOnboarding, first.hasCompletedOnboarding)
    }

    func test_toursCompleted_withValues_roundTripsStably() throws {
        var settings = JunctionSettings()
        settings.toursCompleted = ["postDefault": true, "anotherTour": false]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)

        XCTAssertEqual(decoded.toursCompleted["postDefault"], true)
        XCTAssertEqual(decoded.toursCompleted["anotherTour"], false)
    }
}
