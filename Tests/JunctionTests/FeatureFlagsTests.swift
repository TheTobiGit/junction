import XCTest
@testable import JunctionApp

final class FeatureFlagsTests: XCTestCase {
    func test_clipboardLinkHUDRequiresShipFlagAndUserPreference() {
        XCTAssertFalse(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: true),
            "HUD must stay off for users when shipClipboardLinkHUD is false"
        )
        XCTAssertFalse(
            FeatureFlags.clipboardLinkHUDEnabled(userPreference: false)
        )
    }
}
