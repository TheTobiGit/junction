@testable import JunctionApp
import XCTest

final class FavoriteTargetTests: XCTestCase {

    func test_favoriteTargetKey_defaultsToNil() {
        let settings = JunctionSettings()
        XCTAssertNil(settings.favoriteTargetKey)
    }

    func test_favoriteTargetKey_roundTrips_forApp() throws {
        var settings = JunctionSettings()
        settings.favoriteTargetKey = "app:com.brave.Browser"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)

        XCTAssertEqual(decoded.favoriteTargetKey, "app:com.brave.Browser")
    }

    func test_favoriteTargetKey_roundTrips_forProfile() throws {
        var settings = JunctionSettings()
        settings.favoriteTargetKey = "profile:com.google.Chrome:Default"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)

        XCTAssertEqual(decoded.favoriteTargetKey, "profile:com.google.Chrome:Default")
    }

    func test_legacySettingsJSON_missingFavoriteTargetKey_decodesAsNil() throws {
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
        XCTAssertNil(decoded.favoriteTargetKey)
    }

    func test_favoriteTargetKey_isIndependentOfPinnedTargetKey() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser"]
        settings.setPinnedTargetKey("app:com.apple.Safari")
        settings.favoriteTargetKey = "app:com.brave.Browser"

        XCTAssertEqual(settings.pinnedTargetKey, "app:com.apple.Safari")
        XCTAssertEqual(settings.favoriteTargetKey, "app:com.brave.Browser")
        XCTAssertEqual(settings.targetOrder.first, "app:com.apple.Safari",
                       "favorite must not reorder targets")
    }

    func test_clearingFavorite_setsNilWithoutAffectingPin() {
        var settings = JunctionSettings()
        settings.targetOrder = ["app:com.apple.Safari", "app:com.brave.Browser"]
        settings.setPinnedTargetKey("app:com.apple.Safari")
        settings.favoriteTargetKey = "app:com.brave.Browser"

        settings.favoriteTargetKey = nil

        XCTAssertNil(settings.favoriteTargetKey)
        XCTAssertEqual(settings.pinnedTargetKey, "app:com.apple.Safari")
    }

    func test_resolveFavorite_returnsExactProfileMatch() {
        let safari = makeOption(bundleID: "com.apple.Safari", name: "Safari")
        let braveDefault = makeProfileOption(
            bundleID: "com.brave.Browser",
            name: "Brave",
            profileID: "Default",
            profileLabel: "Default"
        )
        let braveWork = makeProfileOption(
            bundleID: "com.brave.Browser",
            name: "Brave",
            profileID: "Profile 1",
            profileLabel: "Work"
        )
        let options = [safari, braveDefault, braveWork]

        SettingsStore.shared.setFavoriteTargetKey("profile:com.brave.Browser:Profile 1")
        defer { SettingsStore.shared.setFavoriteTargetKey(nil) }

        let resolved = LaunchOptionDiscovery.resolveFavorite(in: options)
        XCTAssertEqual(resolved?.target.storageKey, braveWork.target.storageKey)
    }

    func test_resolveFavorite_fallsBackToBundleWhenProfileMissing() {
        let safari = makeOption(bundleID: "com.apple.Safari", name: "Safari")
        let brave = makeOption(bundleID: "com.brave.Browser", name: "Brave")
        let options = [safari, brave]

        SettingsStore.shared.setFavoriteTargetKey("profile:com.brave.Browser:DeletedProfile")
        defer { SettingsStore.shared.setFavoriteTargetKey(nil) }

        let resolved = LaunchOptionDiscovery.resolveFavorite(in: options)
        XCTAssertEqual(resolved?.browser.bundleID, "com.brave.Browser")
        XCTAssertNil(resolved?.profile, "profile fallback must drop the profile suffix")
    }

    func test_resolveFavorite_returnsNilWhenNoFavoriteSet() {
        SettingsStore.shared.setFavoriteTargetKey(nil)
        let safari = makeOption(bundleID: "com.apple.Safari", name: "Safari")
        XCTAssertNil(LaunchOptionDiscovery.resolveFavorite(in: [safari]))
    }

    // MARK: - Helpers

    private func makeOption(bundleID: String, name: String) -> LaunchOption {
        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        return LaunchOption(browser: Browser(bundleID: bundleID, name: name, url: url), profile: nil)
    }

    private func makeProfileOption(
        bundleID: String,
        name: String,
        profileID: String,
        profileLabel: String
    ) -> LaunchOption {
        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        let browser = Browser(bundleID: bundleID, name: name, url: url)
        let profile = ChromiumProfile(
            directoryName: profileID,
            displayName: profileLabel,
            colorHex: nil
        )
        return LaunchOption(browser: browser, profile: profile)
    }
}
