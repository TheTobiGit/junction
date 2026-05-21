import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-CROSS-003: Path-prefix + per-rule tracker overrides compose
// A DomainRule with host == .equals("github.com"), path == .prefix("/issues"),
// trackerOverrides.additions == ["ref"] matches https://github.com/issues/123?ref=spam.
// Matcher returns this rule, per-rule overrides merge into pipeline, ref is stripped,
// .open action fires against cleaned URL.
final class RuleComposeTests: XCTestCase {

    private func emptyContext() -> RouteContext {
        RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
    }

    // MARK: - VAL-CROSS-003

    func test_pathTrackerOverridesCompose_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/issues/123?ref=spam")!

        XCTAssertTrue(
            rule.matches(url: url, host: "github.com", context: emptyContext()),
            "Rule must match github.com/issues/*"
        )

        let globalOverrides = TrackerOverrides()
        let pipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: rule.trackerOverrides
        )
        let cleaned = pipeline.run(url)

        let components = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(names.contains("ref"),
                       "ref must be stripped by rule-scoped tracker override")
        XCTAssertEqual(cleaned.path, "/issues/123",
                       "Path must be preserved after tracker stripping")
    }

    func test_ruleDoesNotMatchOtherPath_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/pulls/123?ref=spam")!

        XCTAssertFalse(
            rule.matches(url: url, host: "github.com", context: emptyContext()),
            "Rule must NOT match /pulls path when path is .prefix(/issues)"
        )
    }

    func test_ruleTrackerStepAppearsInTrace_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/issues/123?ref=spam")!
        let pipeline = URLTransformers.pipeline(
            globalOverrides: TrackerOverrides(),
            ruleOverrides: rule.trackerOverrides
        )
        let result = pipeline.runTraced(url)

        let stepIdentifiers = result.steps.map { $0.identifier }
        XCTAssertTrue(
            stepIdentifiers.contains("rule-tracker-stripper"),
            "Trace must include 'rule-tracker-stripper' step; got: \(stepIdentifiers)"
        )
    }
}
