import XCTest
@testable import JunctionApp

final class PromoteToRuleRoundTripTests: XCTestCase {

    private func makeTempRulesStore() -> (RulesStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rules-\(UUID().uuidString).json")
        return (RulesStore(fileURL: url), url)
    }

    private func makeEntry(
        cleanedURL: String,
        targetStorageKey: String?,
        targetBundleID: String?
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

    // VAL-CROSS-002: After promoting an entry routed to Brave, routing resolver
    // routes the same host to Brave directly without picker.
    // Profile preserved when targetStorageKey is profile-shaped.
    func test_promoteToRuleRoundTrip_VAL_CROSS_002() {
        let (store, _) = makeTempRulesStore()
        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))

        // App-shaped: Brave entry
        let braveEntry = makeEntry(
            cleanedURL: "https://brave.com/",
            targetStorageKey: "app:com.brave.Browser",
            targetBundleID: "com.brave.Browser"
        )
        let bravePrefill = AddRuleSheet.prefill(for: braveEntry, options: [])!
        store.addRule(DomainRule(host: bravePrefill.host, action: bravePrefill.action!))

        let braveMatch = store.match(url: URL(string: "https://brave.com/page")!, context: context)
        XCTAssertEqual(braveMatch.action, .open(.app(bundleID: "com.brave.Browser")))

        // Profile-shaped: Chrome Work profile entry
        let browser = Browser(
            bundleID: "com.google.Chrome",
            name: "Chrome",
            url: URL(string: "file:///Applications/Chrome.app")!
        )
        let profile = ChromiumProfile(directoryName: "Work", displayName: "Work Profile", colorHex: "#0000FF")
        let option = LaunchOption(browser: browser, profile: profile)

        let chromeEntry = makeEntry(
            cleanedURL: "https://docs.google.com/",
            targetStorageKey: "profile:com.google.Chrome:Work",
            targetBundleID: "com.google.Chrome"
        )
        let chromePrefill = AddRuleSheet.prefill(for: chromeEntry, options: [option])!
        store.addRule(DomainRule(host: chromePrefill.host, action: chromePrefill.action!))

        let chromeMatch = store.match(url: URL(string: "https://docs.google.com/spreadsheets")!, context: context)
        XCTAssertEqual(
            chromeMatch.action,
            .open(.profile(bundleID: "com.google.Chrome", profileID: "Work", label: "Work Profile", colorHex: "#0000FF"))
        )
    }
}
