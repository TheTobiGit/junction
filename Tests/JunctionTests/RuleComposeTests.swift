import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-CROSS-003: Path-prefix + source-app + per-rule tracker overrides compose
// A DomainRule with host == .equals("github.com"), path == .prefix("/issues"),
// condition.sourceApp == ["com.tinyspeck.slackmacgap"], trackerOverrides.additions == ["ref"]
// matches https://github.com/issues/123?ref=spam arriving with Slack source.
// Matcher returns this rule, per-rule overrides merge into pipeline, ref is stripped,
// .open action fires against cleaned URL.
final class RuleComposeTests: XCTestCase {

    private func slackContext() -> RouteContext {
        let source = URLSource(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", icon: nil)
        return RouteContext(source: source, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
    }

    private func emptyContext() -> RouteContext {
        RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
    }

    // MARK: - VAL-CROSS-003

    func test_pathSourceAppTrackerOverridesCompose_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]),
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/issues/123?ref=spam")!
        let slackCtx = slackContext()

        XCTAssertTrue(
            rule.matches(url: url, host: "github.com", context: slackCtx),
            "Rule must match github.com/issues/* from Slack"
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

    func test_ruleDoesNotMatchOtherSourceApp_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]),
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/issues/123?ref=spam")!
        let safariCtx = RouteContext(
            source: URLSource(bundleID: "com.apple.Safari", name: "Safari", icon: nil),
            focus: FocusInfo(modeIdentifier: nil, modeName: nil)
        )

        XCTAssertFalse(
            rule.matches(url: url, host: "github.com", context: safariCtx),
            "Rule must NOT match when source app is Safari, not Slack"
        )
    }

    func test_ruleDoesNotMatchOtherPath_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]),
            path: .prefix("/issues"),
            trackerOverrides: TrackerOverrides(additions: ["ref"], disabled: [])
        )

        let url = URL(string: "https://github.com/pulls/123?ref=spam")!
        let slackCtx = slackContext()

        XCTAssertFalse(
            rule.matches(url: url, host: "github.com", context: slackCtx),
            "Rule must NOT match /pulls path when path is .prefix(/issues)"
        )
    }

    func test_ruleTrackerStepAppearsInTrace_VAL_CROSS_003() {
        let rule = DomainRule(
            host: .equals("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]),
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
