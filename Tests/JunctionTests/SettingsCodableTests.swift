@testable import JunctionApp
import XCTest

final class SettingsCodableTests: XCTestCase {

    // VAL-M3-FRAME-001: pickerFrame encodes as four CGFloats and roundtrips through Codable.
    func test_pickerFrameEncodesAsFourNumericFieldsAndRoundtrips_VAL_M3_FRAME_001() throws {
        var settings = JunctionSettings()
        settings.pickerFrame = CGRect(x: 100, y: 200, width: 480, height: 320)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"pickerFrame\""), "pickerFrame key must be present in JSON")
        XCTAssertTrue(json.contains("\"height\""), "height field must be present")
        XCTAssertTrue(json.contains("\"width\""), "width field must be present")
        XCTAssertTrue(json.contains("\"x\""), "x field must be present")
        XCTAssertTrue(json.contains("\"y\""), "y field must be present")

        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)
        let frame = try XCTUnwrap(decoded.pickerFrame)
        XCTAssertEqual(frame.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 200, accuracy: 0.001)
        XCTAssertEqual(frame.size.width, 480, accuracy: 0.001)
        XCTAssertEqual(frame.size.height, 320, accuracy: 0.001)
    }

    // VAL-M3-FRAME-002: Legacy settings.json without pickerFrame decodes with pickerFrame == nil.
    func test_legacySettingsJSON_missingPickerFrame_decodesAsNil_VAL_M3_FRAME_002() throws {
        let json = """
        {
            "cleanURLsBeforeOpening": true,
            "expandShortenedURLs": true,
            "clipboardWatcherEnabled": false,
            "hiddenTargetKeys": [],
            "targetOrder": ["app:com.apple.Safari"],
            "hasCompletedOnboarding": false,
            "historyEnabled": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: json)
        XCTAssertNil(decoded.pickerFrame)
    }
}
