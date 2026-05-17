import XCTest
@testable import JunctionApp

final class PromoteToRulePrefillTests: XCTestCase {

    private func makeEntry(
        cleanedURL: String = "https://github.com/orgs/acme",
        targetStorageKey: String? = nil,
        targetBundleID: String? = nil
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: cleanedURL,
            cleanedURL: cleanedURL,
            outcome: .opened,
            targetBundleID: targetBundleID,
            ruleLabel: nil,
            cleaningSteps: [],
            sourceBundleID: nil,
            targetStorageKey: targetStorageKey
        )
    }

    private func makeOption(
        bundleID: String,
        profileID: String? = nil,
        profileLabel: String = "Default",
        colorHex: String? = nil
    ) -> LaunchOption {
        let browser = Browser(
            bundleID: bundleID,
            name: bundleID,
            url: URL(string: "file:///Applications/Browser.app")!
        )
        let profile = profileID.map {
            ChromiumProfile(directoryName: $0, displayName: profileLabel, colorHex: colorHex)
        }
        return LaunchOption(browser: browser, profile: profile)
    }

    // VAL-M2-PROMOTE-002: Prefill seeds host = HostMatch.equals(entry.host)
    func test_prefillSeedsHostFromEntry_VAL_M2_PROMOTE_002() {
        let entry = makeEntry(cleanedURL: "https://github.com/orgs/acme")
        let prefill = AddRuleSheet.prefill(for: entry, options: [])
        XCTAssertNotNil(prefill)
        XCTAssertEqual(prefill?.host, .equals("github.com"))
    }

    // VAL-M2-PROMOTE-003: Profile storage key with matching option → .open(.profile(...))
    func test_prefillProfileStorageKey_VAL_M2_PROMOTE_003() {
        let entry = makeEntry(
            cleanedURL: "https://github.com/",
            targetStorageKey: "profile:com.google.Chrome:Default",
            targetBundleID: "com.google.Chrome"
        )
        let option = makeOption(
            bundleID: "com.google.Chrome",
            profileID: "Default",
            profileLabel: "Person 1",
            colorHex: "#FF0000"
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [option])
        XCTAssertEqual(
            prefill?.action,
            .open(.profile(bundleID: "com.google.Chrome", profileID: "Default", label: "Person 1", colorHex: "#FF0000"))
        )
    }

    // VAL-M2-PROMOTE-004: App storage key → .open(.app(bundleID:))
    func test_prefillAppStorageKey_VAL_M2_PROMOTE_004() {
        let entry = makeEntry(
            cleanedURL: "https://apple.com/",
            targetStorageKey: "app:com.apple.Safari",
            targetBundleID: "com.apple.Safari"
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])
        XCTAssertEqual(prefill?.action, .open(.app(bundleID: "com.apple.Safari")))
    }

    // VAL-M2-PROMOTE-005: Missing storage key + non-nil targetBundleID → .open(.app(bundleID:))
    func test_prefillMissingStorageKeyFallsBackToBundleID_VAL_M2_PROMOTE_005() {
        let entry = makeEntry(
            cleanedURL: "https://apple.com/",
            targetStorageKey: nil,
            targetBundleID: "com.apple.Safari"
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])
        XCTAssertEqual(prefill?.action, .open(.app(bundleID: "com.apple.Safari")))
    }

    // VAL-M2-PROMOTE-006: Unresolvable storage key + non-nil targetBundleID → .open(.app(bundleID:))
    func test_prefillUnresolvableStorageKeyFallsBackToBundleID_VAL_M2_PROMOTE_006() {
        let entry = makeEntry(
            cleanedURL: "https://github.com/",
            targetStorageKey: "profile:com.google.Chrome:Personal",
            targetBundleID: "com.google.Chrome"
        )
        let option = makeOption(bundleID: "com.google.Chrome", profileID: "Default", profileLabel: "Person 1")
        let prefill = AddRuleSheet.prefill(for: entry, options: [option])
        XCTAssertEqual(prefill?.action, .open(.app(bundleID: "com.google.Chrome")))
    }

    // VAL-M2-PROMOTE-007: Both storage key and targetBundleID nil → no action
    func test_prefillNoTargetIdentifiers_VAL_M2_PROMOTE_007() {
        let entry = makeEntry(
            cleanedURL: "https://github.com/",
            targetStorageKey: nil,
            targetBundleID: nil
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])
        XCTAssertNil(prefill?.action)
    }
}
