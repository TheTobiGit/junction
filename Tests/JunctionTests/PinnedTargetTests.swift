@testable import JunctionApp
import XCTest

final class PinnedTargetTests: XCTestCase {

    // VAL-M3-PIN-001: Pinning rewrites targetOrder so the pinned key is at index 0;
    // non-pinned keys preserve their relative order.
    func test_pinExistingKey_movesToIndexZero_VAL_M3_PIN_001() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setPinnedTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.pinnedTargetKey, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.first, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder, ["app:com.brave.Browser", "app:com.apple.Safari", "app:com.google.Chrome"])
    }

    // VAL-M3-PIN-002: Pinning a key not present in targetOrder inserts it at index 0.
    func test_pinNewKey_insertsAtIndexZero_VAL_M3_PIN_002() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.google.Chrome"]
        settings.setPinnedTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.first, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.count, 3)
    }

    // VAL-M3-PIN-003: LaunchOptionDiscovery returns the pinned target first.
    func test_applyUserOrder_pinnedKeyFirst_VAL_M3_PIN_003() {
        let safari = makeLaunchOption(bundleID: "com.apple.Safari", name: "Safari")
        let brave = makeLaunchOption(bundleID: "com.brave.Browser", name: "Brave")
        let chrome = makeLaunchOption(bundleID: "com.google.Chrome", name: "Chrome")
        let options = [safari, brave, chrome]
        let order = ["app:com.brave.Browser", "app:com.apple.Safari", "app:com.google.Chrome"]
        let result = LaunchOptionDiscovery.applyUserOrder(options, order: order)
        XCTAssertEqual(result.first?.target.storageKey, "app:com.brave.Browser")
        XCTAssertEqual(result.map { $0.target.storageKey }, order)
    }

    // VAL-M3-PIN-004: Pinning is idempotent; no duplicate entries.
    func test_pinSameKeyTwice_idempotent_VAL_M3_PIN_004() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setPinnedTargetKey("app:com.brave.Browser")
        let afterFirst = settings.targetOrder
        settings.setPinnedTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder, afterFirst)
        XCTAssertEqual(Set(settings.targetOrder).count, settings.targetOrder.count)
    }

    // VAL-M3-PIN-005: Unpinning preserves user-arranged order; previously-pinned key remains.
    func test_unpin_preservesTargetOrder_VAL_M3_PIN_005() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setPinnedTargetKey("app:com.brave.Browser")
        let orderAfterPin = settings.targetOrder
        settings.setPinnedTargetKey(nil)
        XCTAssertNil(settings.pinnedTargetKey)
        XCTAssertEqual(settings.targetOrder, orderAfterPin)
        XCTAssertTrue(settings.targetOrder.contains("app:com.brave.Browser"))
    }

    // VAL-M3-PIN-006: Legacy settings.json without pinnedTargetKey decodes as nil.
    func test_legacySettingsJSON_missingPinnedTargetKey_decodesAsNil_VAL_M3_PIN_006() throws {
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
        XCTAssertNil(decoded.pinnedTargetKey)
        XCTAssertEqual(decoded.targetOrder, ["app:com.apple.Safari"])
    }

    // MARK: - Helpers

    private func makeLaunchOption(bundleID: String, name: String) -> LaunchOption {
        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        let browser = Browser(bundleID: bundleID, name: name, url: url)
        return LaunchOption(browser: browser, profile: nil)
    }
}
