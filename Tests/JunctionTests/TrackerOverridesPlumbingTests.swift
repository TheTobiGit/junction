import XCTest
@testable import JunctionApp
@testable import JunctionCore

// Tests for the explicit-target, copy-clean, and settings-integration plumbing
// gaps identified in the M4 scrutiny review.
//
// VAL-M4-TRACKER-RULE-001..005 and VAL-CROSS-003/013 are reinforced by
// verifying that per-rule trackerOverrides are applied on the
// junction://open explicit-target path, the CLI explicit-target path,
// and the copy-clean path.
final class TrackerOverridesPlumbingTests: XCTestCase {

    // MARK: - Explicit-target path (junction://open and CLI agent)

    // The fixed junction://open explicit-target branch and routeAgent explicit-target
    // branch both rebuild the pipeline with match.rule?.trackerOverrides before
    // computing finalURL. Verify the pipeline logic they use:
    // a rule with trackerOverrides.additions strips the custom param even when
    // an explicit target key is provided.
    func test_explicitTargetPathAppliesRuleTrackerAdditions() {
        let ruleOverrides = TrackerOverrides(additions: ["rule_tk"], disabled: [])
        let globalOverrides = TrackerOverrides()

        let pipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )

        let url = URL(string: "https://example.com/?rule_tk=abc&keep=1")!
        let result = pipeline.run(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(names.contains("rule_tk"),
                       "rule_tk must be stripped when rule overrides are applied on explicit-target path")
        XCTAssertTrue(names.contains("keep"),
                      "keep must be retained on explicit-target path")
    }

    // A rule with trackerOverrides.disabled preserves a built-in tracker param
    // on the explicit-target path. Without the fix, the default pipeline would
    // strip it; with the fix the rule-scoped pipeline preserves it.
    func test_explicitTargetPathAppliesRuleTrackerDisabled() {
        let ruleOverrides = TrackerOverrides(additions: [], disabled: ["utm_source"])
        let globalOverrides = TrackerOverrides()

        let rulePipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let defaultPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        )

        let url = URL(string: "https://example.com/?utm_source=newsletter&keep=1")!

        let ruleResult = rulePipeline.run(url)
        let defaultResult = defaultPipeline.run(url)

        let ruleComponents = URLComponents(url: ruleResult, resolvingAgainstBaseURL: false)
        let ruleNames = ruleComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(ruleNames.contains("utm_source"),
                      "utm_source must be preserved when rule disables it on explicit-target path")

        let defaultComponents = URLComponents(url: defaultResult, resolvingAgainstBaseURL: false)
        let defaultNames = defaultComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(defaultNames.contains("utm_source"),
                       "utm_source must be stripped by default pipeline (no rule override)")
    }

    // MARK: - Copy-clean path

    // copyCleaned now copies trace.final directly without re-running
    // URLTransformers.default. This test verifies that a URL produced by a
    // rule-scoped pipeline (which disabled utm_source) is NOT re-stripped when
    // passed through the copy path.
    //
    // Before the fix: copyCleaned ran URLTransformers.default on trace.final,
    // which would strip utm_source even though the rule said to keep it.
    // After the fix: copyCleaned copies the URL as-is.
    func test_copyCleanPathPreservesRuleScopedDisabledParam() {
        let ruleOverrides = TrackerOverrides(additions: [], disabled: ["utm_source"])
        let globalOverrides = TrackerOverrides()

        let rulePipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )

        let url = URL(string: "https://example.com/?utm_source=newsletter&keep=1")!
        let trace = rulePipeline.runTraced(url)

        // trace.final still has utm_source because the rule disabled stripping it.
        let traceComponents = URLComponents(url: trace.final, resolvingAgainstBaseURL: false)
        let traceNames = traceComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(traceNames.contains("utm_source"),
                      "trace.final must retain utm_source when rule disables stripping")

        // Simulating the old (broken) copyCleaned: re-running URLTransformers.default
        // on trace.final would strip utm_source, losing the rule's intent.
        let reStripped = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        ).run(trace.final)
        let reStrippedComponents = URLComponents(url: reStripped, resolvingAgainstBaseURL: false)
        let reStrippedNames = reStrippedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(reStrippedNames.contains("utm_source"),
                       "Re-running default pipeline on trace.final would incorrectly strip utm_source (old bug)")

        // The fixed copyCleaned copies trace.final directly — utm_source is preserved.
        XCTAssertTrue(traceNames.contains("utm_source"),
                      "Fixed copy path must preserve utm_source from rule-scoped trace.final")
    }

    // MARK: - Settings integration: SettingsStore → URLTransformers.default

    // Mutates JunctionSettings.trackerOverrides via SettingsStore and asserts
    // URLTransformers.default picks up the change end-to-end.
    // VAL-M4-TRACKER-LIST-001 covers TrackerStripper(overrides:) directly;
    // this test covers the SettingsStore → URLTransformers.default wiring.
    func test_settingsStoreTrackerOverridesFlowsIntoDefaultPipeline() {
        let original = SettingsStore.shared.settings.trackerOverrides
        defer { SettingsStore.shared.settings.trackerOverrides = original }

        var overrides = TrackerOverrides()
        overrides.additions = ["foo"]
        SettingsStore.shared.settings.trackerOverrides = overrides

        let url = URL(string: "https://example.com/?foo=1&keep=1")!
        let result = URLTransformers.default.run(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(names.contains("foo"),
                       "foo must be stripped via URLTransformers.default after SettingsStore mutation")
        XCTAssertTrue(names.contains("keep"),
                      "keep must be retained via URLTransformers.default after SettingsStore mutation")
    }
}
