import XCTest
@testable import JunctionApp

final class FeatureFlagsTests: XCTestCase {
    func test_clipboardLinkHUDRequiresShipFlagAndUserPreference() {
        let noOverride: [String: String] = [:]
        XCTAssertFalse(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: true, environment: noOverride),
            "HUD must stay off for users when shipClipboardLinkHUD is false"
        )
        XCTAssertFalse(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: false, environment: noOverride)
        )
    }

    func test_clipboardLinkHUDLocalOverrideRequiresUserPreference() {
        let override = ["JUNCTION_CLIPBOARD_HUD": "1"]
        XCTAssertTrue(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: true, environment: override)
        )
        XCTAssertFalse(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: false, environment: override)
        )
    }
}
