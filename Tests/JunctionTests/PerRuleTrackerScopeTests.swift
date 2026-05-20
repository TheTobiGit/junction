import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-CROSS-013: Per-rule tracker overrides do not leak across hosts
// ruleX for github.com with additions = ["rule_ref"]; ruleY for example.com no overrides.
// Processing https://example.com/?rule_ref=spam matches ruleY, global tracker list does
// not strip rule_ref, URL retains ?rule_ref=spam. Same URL with host github.com strips rule_ref.
final class PerRuleTrackerScopeTests: XCTestCase {

    private func context(bundleID: String? = nil) -> RouteContext {
        let source = bundleID.map { URLSource(bundleID: $0, name: $0, icon: nil) }
        return RouteContext(source: source, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
    }

    // MARK: - VAL-CROSS-013

    func test_ruleOverrideDoesNotLeakToOtherHost_VAL_CROSS_013() {
        let globalOverrides = TrackerOverrides()

        // rule_ref is not in the global strip list — only the github.com rule adds it
        let githubRuleOverrides = TrackerOverrides(additions: ["rule_ref"], disabled: [])
        let githubPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: githubRuleOverrides
        )
        let examplePipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        )

        let githubURL = URL(string: "https://github.com/?rule_ref=spam&keep=1")!
        let exampleURL = URL(string: "https://example.com/?rule_ref=spam&keep=1")!

        let githubResult = githubPipeline.run(githubURL)
        let exampleResult = examplePipeline.run(exampleURL)

        let githubComponents = URLComponents(url: githubResult, resolvingAgainstBaseURL: false)
        let githubNames = githubComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(githubNames.contains("rule_ref"),
                       "rule_ref must be stripped from github.com URL when rule override applies")

        let exampleComponents = URLComponents(url: exampleResult, resolvingAgainstBaseURL: false)
        let exampleNames = exampleComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(exampleNames.contains("rule_ref"),
                      "rule_ref must NOT be stripped from example.com URL — github.com rule must not leak")
        XCTAssertTrue(exampleNames.contains("keep"),
                      "keep param must be retained on example.com")
    }

    func test_ruleOverrideAppliesOnlyToMatchedHost_VAL_CROSS_013() {
        let globalOverrides = TrackerOverrides()
        let ruleOverrides = TrackerOverrides(additions: ["custom_token"], disabled: [])

        let matchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let unmatchedPipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: nil
        )

        let matchedURL = URL(string: "https://github.com/?custom_token=abc&keep=1")!
        let unmatchedURL = URL(string: "https://example.com/?custom_token=abc&keep=1")!

        let matchedResult = matchedPipeline.run(matchedURL)
        let unmatchedResult = unmatchedPipeline.run(unmatchedURL)

        let matchedComponents = URLComponents(url: matchedResult, resolvingAgainstBaseURL: false)
        let matchedNames = matchedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(matchedNames.contains("custom_token"),
                       "custom_token must be stripped on matched host")

        let unmatchedComponents = URLComponents(url: unmatchedResult, resolvingAgainstBaseURL: false)
        let unmatchedNames = unmatchedComponents?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(unmatchedNames.contains("custom_token"),
                      "custom_token must be kept on unmatched host")
    }
}
