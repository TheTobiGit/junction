@testable import JunctionApp
import XCTest

final class JunctionSettingsCodableTests: XCTestCase {

    // VAL-M4-TRACKER-LIST-005: JunctionSettings forward-compat decode.
    // A settings.json missing trackerOverrides decodes successfully with empty additions and disabled lists.
    func test_legacySettingsJSON_missingTrackerOverrides_decodesWithEmptyOverrides_VAL_M4_TRACKER_LIST_005() throws {
        let json = """
        {
            "cleanURLsBeforeOpening": true,
            "expandShortenedURLs": true,
            "clipboardWatcherEnabled": false,
            "hiddenTargetKeys": [],
            "targetOrder": [],
            "hasCompletedOnboarding": false,
            "historyEnabled": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: json)
        XCTAssertTrue(decoded.trackerOverrides.additions.isEmpty, "additions must default to empty")
        XCTAssertTrue(decoded.trackerOverrides.disabled.isEmpty, "disabled must default to empty")
    }

    // Round-trip: trackerOverrides encodes and decodes with values preserved.
    func test_trackerOverridesRoundTrip() throws {
        var settings = JunctionSettings()
        settings.trackerOverrides.additions = ["custom_tk", "mc_"]
        settings.trackerOverrides.disabled = ["utm_source", "fbclid"]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)

        XCTAssertEqual(decoded.trackerOverrides.additions, ["custom_tk", "mc_"])
        XCTAssertEqual(decoded.trackerOverrides.disabled, ["utm_source", "fbclid"])
    }
}
