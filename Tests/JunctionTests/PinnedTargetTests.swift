@testable import JunctionApp
import XCTest

final class PinnedTargetTests: XCTestCase {

    // VAL-M3-PIN-001: Setting favorite rewrites targetOrder so the favored key is at index 0;
    // non-favored keys preserve their relative order.
    func test_favoriteExistingKey_movesToIndexZero_VAL_M3_PIN_001() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setFavoriteTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.favoriteTargetKey, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.first, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder, ["app:com.brave.Browser", "app:com.apple.Safari", "app:com.google.Chrome"])
    }

    // VAL-M3-PIN-002: Favoriting a key not present in targetOrder inserts it at index 0.
    func test_favoriteNewKey_insertsAtIndexZero_VAL_M3_PIN_002() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.google.Chrome"]
        settings.setFavoriteTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.first, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.count, 3)
    }

    // VAL-M3-PIN-003: Explicit target ordering places options in the order provided.
    func test_applyUserOrder_respectsProvidedOrder_VAL_M3_PIN_003() {
        let safari = makeLaunchOption(bundleID: "com.apple.Safari", name: "Safari")
        let brave = makeLaunchOption(bundleID: "com.brave.Browser", name: "Brave")
        let chrome = makeLaunchOption(bundleID: "com.google.Chrome", name: "Chrome")
        let options = [safari, brave, chrome]
        let order = ["app:com.brave.Browser", "app:com.apple.Safari", "app:com.google.Chrome"]
        let result = LaunchOptionDiscovery.applyUserOrder(options, order: order)
        XCTAssertEqual(result.first?.target.storageKey, "app:com.brave.Browser")
        XCTAssertEqual(result.map { $0.target.storageKey }, order)
    }

    // VAL-M3-PIN-004: Favoriting is idempotent; no duplicate entries.
    func test_favoriteSameKeyTwice_idempotent_VAL_M3_PIN_004() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setFavoriteTargetKey("app:com.brave.Browser")
        let afterFirst = settings.targetOrder
        settings.setFavoriteTargetKey("app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder, afterFirst)
        XCTAssertEqual(Set(settings.targetOrder).count, settings.targetOrder.count)
    }

    // VAL-M3-PIN-005: Clearing the favorite preserves user-arranged order; previously-favored key remains.
    func test_clearFavorite_preservesTargetOrder_VAL_M3_PIN_005() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser", "app:com.google.Chrome"]
        settings.setFavoriteTargetKey("app:com.brave.Browser")
        let orderAfterFavorite = settings.targetOrder
        settings.setFavoriteTargetKey(nil)
        XCTAssertNil(settings.favoriteTargetKey)
        XCTAssertEqual(settings.targetOrder, orderAfterFavorite)
        XCTAssertTrue(settings.targetOrder.contains("app:com.brave.Browser"))
    }

    // VAL-M3-PIN-006: Legacy settings.json with pinnedTargetKey migrates into favoriteTargetKey.
    func test_legacySettingsJSON_pinnedTargetKey_migratesToFavorite_VAL_M3_PIN_006() throws {
        let json = """
        {
            "cleanURLsBeforeOpening": true,
            "expandShortenedURLs": true,
            "clipboardWatcherEnabled": false,
            "hiddenTargetKeys": [],
            "targetOrder": ["app:com.brave.Browser", "app:com.apple.Safari"],
            "hasCompletedOnboarding": false,
            "historyEnabled": true,
            "pinnedTargetKey": "app:com.brave.Browser"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: json)
        XCTAssertEqual(decoded.favoriteTargetKey, "app:com.brave.Browser",
                       "legacy pinnedTargetKey must migrate into favoriteTargetKey")
        XCTAssertEqual(decoded.targetOrder, ["app:com.brave.Browser", "app:com.apple.Safari"])
    }

    // MARK: - Helpers

    private func makeLaunchOption(bundleID: String, name: String) -> LaunchOption {
        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        let browser = Browser(bundleID: bundleID, name: name, url: url)
        return LaunchOption(browser: browser, profile: nil)
    }
}
