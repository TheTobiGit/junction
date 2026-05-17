@testable import JunctionApp
import XCTest

final class TrackerOverridesTests: XCTestCase {

    // VAL-M4-TRACKER-LIST-001: Custom tracker addition strips param.
    // With trackerOverrides.additions = ["custom_tk"], applying URLTransformers.default
    // to https://x.com/?custom_tk=1 returns https://x.com/.
    func test_customAdditionStripsParam_VAL_M4_TRACKER_LIST_001() {
        var overrides = TrackerOverrides()
        overrides.additions = ["custom_tk"]
        let stripper = TrackerStripper(overrides: overrides)
        let url = URL(string: "https://x.com/?custom_tk=1")!
        let result = stripper.transform(url)
        XCTAssertEqual(result.absoluteString, "https://x.com/")
    }

    // VAL-M4-TRACKER-LIST-002: Disabled built-in tracker is preserved.
    // With trackerOverrides.disabled = ["utm_source"], applying pipeline to
    // https://x.com/?utm_source=newsletter&keep=1 retains utm_source=newsletter.
    func test_disabledBuiltInTrackerIsPreserved_VAL_M4_TRACKER_LIST_002() {
        var overrides = TrackerOverrides()
        overrides.disabled = ["utm_source"]
        let stripper = TrackerStripper(overrides: overrides)
        let url = URL(string: "https://x.com/?utm_source=newsletter&keep=1")!
        let result = stripper.transform(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(names.contains("utm_source"), "utm_source must be preserved when disabled")
        XCTAssertTrue(names.contains("keep"), "keep param must be retained")
    }

    // VAL-M4-TRACKER-LIST-003: Empty overrides match today's pipeline behavior byte-for-byte.
    // With trackerOverrides empty (default), pipeline output for fixture URLs matches pre-M4 baseline.
    func test_emptyOverridesMatchBaselineBehavior_VAL_M4_TRACKER_LIST_003() {
        let defaultStripper = TrackerStripper()
        let overrideStripper = TrackerStripper(overrides: TrackerOverrides())

        let fixtures: [String] = [
            "https://example.com/?utm_source=newsletter&utm_medium=email&keep=1",
            "https://example.com/?fbclid=abc123&ref=home",
            "https://example.com/?gclid=xyz&q=search",
            "https://example.com/?no_tracker=1&other=2",
            "https://x.com/?s=abc&t=def&keep=me",
        ]

        for urlString in fixtures {
            let url = URL(string: urlString)!
            let baseline = defaultStripper.transform(url)
            let withOverrides = overrideStripper.transform(url)
            XCTAssertEqual(
                baseline.absoluteString,
                withOverrides.absoluteString,
                "Empty overrides must produce identical output for \(urlString)"
            )
        }
    }

    // VAL-M4-TRACKER-LIST-004: Custom prefix addition strips by prefix.
    // With trackerOverrides.additions = ["mc_"] (prefix entry ending in _),
    // pipeline strips mc_eid=123 while keeping keep=1.
    func test_customPrefixAdditionStripsByPrefix_VAL_M4_TRACKER_LIST_004() {
        var overrides = TrackerOverrides()
        overrides.additions = ["mc_"]
        let stripper = TrackerStripper(overrides: overrides)
        let url = URL(string: "https://example.com/?mc_eid=123&keep=1")!
        let result = stripper.transform(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(names.contains("mc_eid"), "mc_eid must be stripped by mc_ prefix addition")
        XCTAssertTrue(names.contains("keep"), "keep param must be retained")
    }
}
