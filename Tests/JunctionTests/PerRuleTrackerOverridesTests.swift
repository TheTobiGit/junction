import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-M4-TRACKER-RULE-001: Rule-scoped addition strips only on match
// VAL-M4-TRACKER-RULE-002: Rule-scoped disable preserves only on match
// VAL-M4-TRACKER-RULE-003: Rules without overrides unchanged
// VAL-M4-TRACKER-RULE-004: DomainRule Codable forward-compat
// VAL-M4-TRACKER-RULE-005: Pipeline records rule-scoped tracker step
final class PerRuleTrackerOverridesTests: XCTestCase {

    private let emptyContext = RouteContext(
        source: nil,
        focus: FocusInfo(modeIdentifier: nil, modeName: nil)
    )

    // MARK: - VAL-M4-TRACKER-RULE-001

    // Rule matching host "x.com" with trackerOverrides.additions = ["xyz"] strips
    // xyz=1 from https://x.com/?xyz=1 while https://other.com/?xyz=1 keeps it.
    func test_ruleAdditionStripsOnlyOnMatch_VAL_M4_TRACKER_RULE_001() {
        let ruleOverrides = TrackerOverrides(additions: ["xyz"], disabled: [])
        let globalOverrides = TrackerOverrides()

        let matchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let unmatchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        )

        let matchedURL = URL(string: "https://x.com/?xyz=1")!
        let unmatchedURL = URL(string: "https://other.com/?xyz=1")!

        let matchedResult = matchedPipeline.run(matchedURL)
        let unmatchedResult = unmatchedPipeline.run(unmatchedURL)

        XCTAssertEqual(matchedResult.absoluteString, "https://x.com/",
                       "xyz must be stripped when rule overrides apply")
        let unmatchedComponents = URLComponents(url: unmatchedResult, resolvingAgainstBaseURL: false)
        let unmatchedNames = unmatchedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(unmatchedNames.contains("xyz"),
                      "xyz must be kept when no rule overrides apply")
    }

    // MARK: - VAL-M4-TRACKER-RULE-002

    // Rule matching host "x.com" with trackerOverrides.disabled = ["utm_source"] keeps
    // utm_source on x.com while still stripping it on other.com.
    func test_ruleDisablePreservesOnlyOnMatch_VAL_M4_TRACKER_RULE_002() {
        let ruleOverrides = TrackerOverrides(additions: [], disabled: ["utm_source"])
        let globalOverrides = TrackerOverrides()

        let matchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let unmatchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        )

        let matchedURL = URL(string: "https://x.com/?utm_source=newsletter&keep=1")!
        let unmatchedURL = URL(string: "https://other.com/?utm_source=newsletter&keep=1")!

        let matchedResult = matchedPipeline.run(matchedURL)
        let unmatchedResult = unmatchedPipeline.run(unmatchedURL)

        let matchedComponents = URLComponents(url: matchedResult, resolvingAgainstBaseURL: false)
        let matchedNames = matchedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(matchedNames.contains("utm_source"),
                      "utm_source must be preserved when rule disables it")

        let unmatchedComponents = URLComponents(url: unmatchedResult, resolvingAgainstBaseURL: false)
        let unmatchedNames = unmatchedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(unmatchedNames.contains("utm_source"),
                       "utm_source must still be stripped when no rule override applies")
    }

    // MARK: - VAL-M4-TRACKER-RULE-003

    // Rules with trackerOverrides == nil produce byte-identical pipeline output
    // to pre-M4 behavior on a 5-URL fixture set.
    func test_noOverridesProducesIdenticalOutput_VAL_M4_TRACKER_RULE_003() {
        let globalOverrides = TrackerOverrides()
        let baselinePipeline = URLTransformers.pipeline(globalOverrides: globalOverrides, ruleOverrides: nil)
        let nilOverridePipeline = URLTransformers.pipeline(globalOverrides: globalOverrides, ruleOverrides: nil)

        let fixtures: [String] = [
            "https://example.com/?utm_source=newsletter&utm_medium=email&keep=1",
            "https://example.com/?fbclid=abc123&ref=home",
            "https://example.com/?gclid=xyz&q=search",
            "https://example.com/?no_tracker=1&other=2",
            "https://x.com/?s=abc&t=def&keep=me",
        ]

        for urlString in fixtures {
            let url = URL(string: urlString)!
            let baseline = baselinePipeline.run(url)
            let withNilOverride = nilOverridePipeline.run(url)
            XCTAssertEqual(
                baseline.absoluteString,
                withNilOverride.absoluteString,
                "nil overrides must produce identical output for \(urlString)"
            )
        }
    }

    // MARK: - VAL-M4-TRACKER-RULE-004

    // A rules.json entry missing trackerOverrides decodes with trackerOverrides == nil.
    func test_legacyRuleDecodesWithNilTrackerOverrides_VAL_M4_TRACKER_RULE_004() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "host": {"kind": "suffix", "value": "github.com"},
            "action": {"kind": "ask"},
            "enabled": true
        }
        """
        let data = json.data(using: .utf8)!
        let rule = try JSONDecoder().decode(DomainRule.self, from: data)
        XCTAssertNil(rule.trackerOverrides, "Legacy rule without trackerOverrides must decode with nil")
    }

    // Round-trip: a rule with trackerOverrides encodes and decodes losslessly.
    func test_trackerOverridesRoundTrips_VAL_M4_TRACKER_RULE_004() throws {
        let overrides = TrackerOverrides(additions: ["xyz", "ref"], disabled: ["utm_source"])
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            trackerOverrides: overrides
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(DomainRule.self, from: data)
        XCTAssertEqual(decoded.trackerOverrides?.additions, ["xyz", "ref"])
        XCTAssertEqual(decoded.trackerOverrides?.disabled, ["utm_source"])
    }

    // MARK: - VAL-M4-TRACKER-RULE-005

    // When a rule with trackerOverrides matches, URLTransformResult.steps contains
    // a step with identifier "rule-tracker-stripper".
    func test_pipelineRecordsRuleScopedTrackerStep_VAL_M4_TRACKER_RULE_005() {
        let ruleOverrides = TrackerOverrides(additions: ["xyz"], disabled: [])
        let globalOverrides = TrackerOverrides()

        let pipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )

        let url = URL(string: "https://x.com/?xyz=1")!
        let result = pipeline.runTraced(url)

        let stepIdentifiers = result.steps.map { $0.identifier }
        XCTAssertTrue(
            stepIdentifiers.contains("rule-tracker-stripper"),
            "Steps must include 'rule-tracker-stripper' when rule overrides fired; got: \(stepIdentifiers)"
        )
    }

    // When no rule overrides, the step identifier is "tracker-stripper" (not rule-scoped).
    func test_pipelineRecordsGlobalTrackerStepWhenNoRuleOverrides_VAL_M4_TRACKER_RULE_005() {
        let globalOverrides = TrackerOverrides()
        let pipeline = URLTransformers.pipeline(globalOverrides: globalOverrides, ruleOverrides: nil)

        let url = URL(string: "https://x.com/?utm_source=test")!
        let result = pipeline.runTraced(url)

        let stepIdentifiers = result.steps.map { $0.identifier }
        XCTAssertTrue(
            stepIdentifiers.contains("tracker-stripper"),
            "Steps must include 'tracker-stripper' when no rule overrides; got: \(stepIdentifiers)"
        )
        XCTAssertFalse(
            stepIdentifiers.contains("rule-tracker-stripper"),
            "Steps must NOT include 'rule-tracker-stripper' when no rule overrides"
        )
    }
}
