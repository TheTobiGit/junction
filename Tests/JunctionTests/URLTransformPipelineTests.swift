import XCTest
@testable import JunctionApp
@testable import JunctionCore

// URLTransformPipeline tests for per-rule tracker override integration.
// Covers pipeline building with and without rule overrides, step identifier
// correctness, and merged override semantics.
final class URLTransformPipelineTests: XCTestCase {

    func test_pipelineWithRuleOverridesUsesRuleTrackerStepIdentifier() {
        let ruleOverrides = TrackerOverrides(additions: ["custom_tk"], disabled: [])
        let pipeline = URLTransformers.pipeline(
            globalOverrides: TrackerOverrides(),
            ruleOverrides: ruleOverrides
        )
        let url = URL(string: "https://example.com/?custom_tk=1")!
        let result = pipeline.runTraced(url)
        let identifiers = result.steps.map { $0.identifier }
        XCTAssertTrue(identifiers.contains("rule-tracker-stripper"))
        XCTAssertFalse(identifiers.contains("tracker-stripper"))
    }

    func test_pipelineWithoutRuleOverridesUsesGlobalTrackerStepIdentifier() {
        let pipeline = URLTransformers.pipeline(
            globalOverrides: TrackerOverrides(),
            ruleOverrides: nil
        )
        let url = URL(string: "https://example.com/?utm_source=test")!
        let result = pipeline.runTraced(url)
        let identifiers = result.steps.map { $0.identifier }
        XCTAssertTrue(identifiers.contains("tracker-stripper"))
        XCTAssertFalse(identifiers.contains("rule-tracker-stripper"))
    }

    func test_ruleAdditionsLayerOnTopOfGlobalOverrides() {
        let globalOverrides = TrackerOverrides(additions: ["global_tk"], disabled: [])
        let ruleOverrides = TrackerOverrides(additions: ["rule_tk"], disabled: [])
        let pipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let url = URL(string: "https://example.com/?global_tk=1&rule_tk=2&keep=3")!
        let result = pipeline.run(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertFalse(names.contains("global_tk"), "global_tk must be stripped (global addition)")
        XCTAssertFalse(names.contains("rule_tk"), "rule_tk must be stripped (rule addition)")
        XCTAssertTrue(names.contains("keep"), "keep must be retained")
    }

    func test_ruleDisabledLayersOnTopOfGlobalDisabled() {
        let globalOverrides = TrackerOverrides(additions: [], disabled: ["fbclid"])
        let ruleOverrides = TrackerOverrides(additions: [], disabled: ["utm_source"])
        let pipeline = URLTransformers.pipeline(
            globalOverrides: globalOverrides,
            ruleOverrides: ruleOverrides
        )
        let url = URL(string: "https://example.com/?fbclid=abc&utm_source=test&gclid=xyz")!
        let result = pipeline.run(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let names = components?.queryItems?.map { $0.name } ?? []
        XCTAssertTrue(names.contains("fbclid"), "fbclid must be preserved (globally disabled)")
        XCTAssertTrue(names.contains("utm_source"), "utm_source must be preserved (rule disabled)")
        XCTAssertFalse(names.contains("gclid"), "gclid must still be stripped (not disabled)")
    }

    func test_nilRuleOverridesProducesSameOutputAsDefaultPipeline() {
        let globalOverrides = TrackerOverrides()
        let pipeline = URLTransformers.pipeline(globalOverrides: globalOverrides, ruleOverrides: nil)
        let defaultStripper = TrackerStripper(overrides: globalOverrides)

        let fixtures: [String] = [
            "https://example.com/?utm_source=newsletter&utm_medium=email",
            "https://example.com/?fbclid=abc123",
            "https://example.com/?no_tracker=1",
        ]

        for urlString in fixtures {
            let url = URL(string: urlString)!
            let pipelineResult = pipeline.run(url)
            let stripperResult = defaultStripper.transform(url)
            XCTAssertEqual(
                pipelineResult.absoluteString,
                stripperResult.absoluteString,
                "nil rule overrides must match default stripper for \(urlString)"
            )
        }
    }
}
