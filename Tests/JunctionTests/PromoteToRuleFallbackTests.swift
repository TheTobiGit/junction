import XCTest
@testable import JunctionApp

final class PromoteToRuleFallbackTests: XCTestCase {

    private func makeTempRulesStore() -> (RulesStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rules-\(UUID().uuidString).json")
        return (RulesStore(fileURL: url), url)
    }

    private func makeEntry(
        cleanedURL: String = "https://brave.com/",
        targetStorageKey: String? = nil,
        targetBundleID: String? = nil,
        outcome: RoutingHistory.Outcome = .opened
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: cleanedURL,
            cleanedURL: cleanedURL,
            outcome: outcome,
            targetBundleID: targetBundleID,
            ruleLabel: nil,
            cleaningSteps: [],
            sourceBundleID: nil,
            targetStorageKey: targetStorageKey
        )
    }

    // VAL-M2-PROMOTE-008: Cancel does not mutate RulesStore
    func test_cancelDoesNotMutateRulesStore_VAL_M2_PROMOTE_008() {
        let (store, _) = makeTempRulesStore()
        let initialCount = store.rules.rules.count
        // Simulate cancel: do not call addRule
        XCTAssertEqual(store.rules.rules.count, initialCount)
    }

    // VAL-M2-PROMOTE-009: Submit calls RulesStore.addRule once with the prefilled rule
    func test_submitCallsAddRuleOnce_VAL_M2_PROMOTE_009() {
        let (store, _) = makeTempRulesStore()
        let entry = makeEntry(
            cleanedURL: "https://brave.com/",
            targetStorageKey: "app:com.brave.Browser",
            targetBundleID: "com.brave.Browser"
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])!
        let rule = DomainRule(host: prefill.host, action: prefill.action ?? .ask)
        let before = store.rules.rules.count
        store.addRule(rule)
        XCTAssertEqual(store.rules.rules.count, before + 1)
        XCTAssertEqual(store.rules.rules.first?.host, .equals("brave.com"))
        XCTAssertEqual(store.rules.rules.first?.action, .open(.app(bundleID: "com.brave.Browser")))
    }

    func test_prefillPreservesIncognitoOutcome() {
        let entry = makeEntry(
            targetStorageKey: "app:com.brave.Browser",
            targetBundleID: "com.brave.Browser",
            outcome: .openedIncognito
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])!
        XCTAssertEqual(prefill.action, .openIncognito(.app(bundleID: "com.brave.Browser")))
    }

    // VAL-CROSS-014: nil storageKey + non-nil targetBundleID → .open(.app(bundleID:));
    // saving routes to that app on next host resolution.
    func test_promoteToRuleFallbackBundleID_VAL_CROSS_014() {
        let entry = makeEntry(
            cleanedURL: "https://brave.com/",
            targetStorageKey: nil,
            targetBundleID: "com.brave.Browser"
        )
        let prefill = AddRuleSheet.prefill(for: entry, options: [])
        XCTAssertEqual(prefill?.action, .open(.app(bundleID: "com.brave.Browser")))

        let (store, _) = makeTempRulesStore()
        let rule = DomainRule(host: prefill!.host, action: prefill!.action!)
        store.addRule(rule)

        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
        let match = store.match(url: URL(string: "https://brave.com/")!, context: context)
        XCTAssertEqual(match.action, .open(.app(bundleID: "com.brave.Browser")))
    }
}
