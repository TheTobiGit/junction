@testable import JunctionApp
import XCTest

final class OnboardingTourManagerTests: XCTestCase {

    // VAL-M6-TOUR-001: toursCompleted encodes round-trip with values preserved.
    func test_toursCompletedEncodesAndDecodesRoundTrip_VAL_M6_TOUR_001() throws {
        var settings = JunctionSettings()
        settings.toursCompleted = ["postDefault": true]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: data)

        XCTAssertEqual(decoded.toursCompleted["postDefault"], true)
    }

    // VAL-M6-TOUR-002: Legacy settings.json without toursCompleted decodes with empty dict default.
    func test_legacySettingsJSON_missingToursCompleted_decodesWithEmptyDict_VAL_M6_TOUR_002() throws {
        let json = """
        {
            "cleanURLsBeforeOpening": true,
            "expandShortenedURLs": true,
            "clipboardWatcherEnabled": false,
            "hiddenTargetKeys": [],
            "targetOrder": [],
            "hasCompletedOnboarding": true,
            "historyEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(JunctionSettings.self, from: json)
        XCTAssertTrue(decoded.toursCompleted.isEmpty, "toursCompleted must default to empty dict")
    }

    // VAL-M6-TOUR-003: shouldShowPostDefaultTour returns true when status is default AND tour not
    // completed AND onboarding completed.
    func test_shouldShowPostDefaultTour_returnsTrue_whenDefaultAndNotCompleted_VAL_M6_TOUR_003() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        XCTAssertTrue(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // VAL-M6-TOUR-004: shouldShowPostDefaultTour returns false when not default.
    func test_shouldShowPostDefaultTour_returnsFalse_whenNotDefault_VAL_M6_TOUR_004() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: false)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // VAL-M6-TOUR-005: shouldShowPostDefaultTour returns false when already completed.
    func test_shouldShowPostDefaultTour_returnsFalse_whenAlreadyCompleted_VAL_M6_TOUR_005() {
        var settings = JunctionSettings()
        settings.hasCompletedOnboarding = true
        settings.toursCompleted = ["postDefault": true]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)
        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status))
    }

    // VAL-M6-TOUR-006: markPostDefaultTourComplete sets the flag in-memory AND persists to disk.
    func test_markPostDefaultTourComplete_setsInMemoryAndPersistsToDisk_VAL_M6_TOUR_006() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: fileURL)
        store.settings.hasCompletedOnboarding = true
        store.settings.toursCompleted = [:]

        OnboardingTourManager.markPostDefaultTourComplete(store: store)

        XCTAssertEqual(store.settings.toursCompleted["postDefault"], true,
                       "in-memory flag must be set")

        let data = try Data(contentsOf: fileURL)
        let persisted = try JSONDecoder().decode(JunctionSettings.self, from: data)
        XCTAssertEqual(persisted.toursCompleted["postDefault"], true,
                       "persisted JSON must reflect the flag")
    }

    // VAL-M6-TOUR-007: Tour does not retrigger after completion (one-shot semantics).
    func test_shouldShowPostDefaultTour_returnsFalse_afterMarkComplete_VAL_M6_TOUR_007() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SettingsStore(fileURL: dir.appendingPathComponent("settings.json"))
        store.settings.hasCompletedOnboarding = true
        store.settings.toursCompleted = [:]

        let status = DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: true)

        XCTAssertTrue(OnboardingTourManager.shouldShowPostDefaultTour(
            settings: store.settings, status: status))

        OnboardingTourManager.markPostDefaultTourComplete(store: store)

        XCTAssertFalse(OnboardingTourManager.shouldShowPostDefaultTour(
            settings: store.settings, status: status),
            "tour must not retrigger after markPostDefaultTourComplete")
    }
}
