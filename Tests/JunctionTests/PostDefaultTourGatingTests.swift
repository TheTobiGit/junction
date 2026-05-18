@testable import JunctionApp
import XCTest

// VAL-CROSS-010: Onboarding tour does not trigger during first-launch onboarding.
// Drives four state combinations of (isDefault, hasCompletedOnboarding).
final class PostDefaultTourGatingTests: XCTestCase {

    // Combination 1: not default, onboarding not complete → false
    func test_notDefault_onboardingNotComplete_returnsFalse() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = false
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: false)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // Combination 2: default, onboarding NOT complete → false (tour must not fire during first-launch)
    func test_isDefault_onboardingNotComplete_returnsFalse_VAL_CROSS_010() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = false
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status),
                       "tour must not fire while first-launch onboarding is incomplete")
    }

    // Combination 3: not default, onboarding complete → false
    func test_notDefault_onboardingComplete_returnsFalse() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: false)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // Combination 4: default, onboarding complete, tour not yet shown → true
    func test_isDefault_onboardingComplete_tourNotShown_returnsTrue() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        XCTAssertTrue(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // After completion: default, onboarding complete, tour already shown → false (one-shot)
    func test_isDefault_onboardingComplete_tourAlreadyShown_returnsFalse() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = ["postDefault": true]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // Verify tour fires exactly once: mark complete then flip default away and back → still false
    func test_tourDoesNotRetriggerAfterDefaultBrowserFlips() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SettingsStore(fileURL: dir.appendingPathComponent("settings.json"))
        store.settings.hasCompletedOnboarding = true
        store.settings.toursCompleted = [:]

        let defaultStatus = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        let nonDefaultStatus = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: false)

        XCTAssertTrue(OnboardingTourManager.shouldShowPostDefaultTour(
            settings: store.settings, status: defaultStatus))

        OnboardingTourManager.markPostDefaultTourComplete(store: store)

        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(
            settings: store.settings, status: nonDefaultStatus),
            "should be false when not default")

        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(
            settings: store.settings, status: defaultStatus),
            "should remain false after default flips back — one-shot semantics")
    }
}
