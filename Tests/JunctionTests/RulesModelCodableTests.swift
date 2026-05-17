import XCTest
@testable import JunctionApp

// VAL-M4-TRACKER-RULE-004: DomainRule Codable forward-compat
// A rules.json entry missing trackerOverrides decodes with trackerOverrides == nil;
// round-trip lossless.
final class RulesModelCodableTests: XCTestCase {

    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    // MARK: - VAL-M4-TRACKER-RULE-004

    func test_legacyRuleWithoutTrackerOverridesDecodesWithNil_VAL_M4_TRACKER_RULE_004() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "host": {"kind": "suffix", "value": "github.com"},
            "action": {"kind": "ask"},
            "enabled": true
        }
        """
        let rule = try decoder.decode(DomainRule.self, from: json.data(using: .utf8)!)
        XCTAssertNil(rule.trackerOverrides,
                     "Legacy rule without trackerOverrides must decode with nil")
    }

    func test_ruleWithTrackerOverridesRoundTrips_VAL_M4_TRACKER_RULE_004() throws {
        let overrides = TrackerOverrides(additions: ["xyz", "ref"], disabled: ["utm_source"])
        let original = DomainRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            host: .suffix("github.com"),
            action: .ask,
            trackerOverrides: overrides
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DomainRule.self, from: data)

        XCTAssertEqual(decoded.trackerOverrides?.additions, ["xyz", "ref"])
        XCTAssertEqual(decoded.trackerOverrides?.disabled, ["utm_source"])
        XCTAssertEqual(decoded.host, original.host)
    }

    func test_ruleWithNilTrackerOverridesRoundTrips_VAL_M4_TRACKER_RULE_004() throws {
        let original = DomainRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            host: .equals("example.com"),
            action: .block,
            trackerOverrides: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DomainRule.self, from: data)
        XCTAssertNil(decoded.trackerOverrides)
    }

    func test_legacyRulesFileDecodesWithNilTrackerOverrides_VAL_M4_TRACKER_RULE_004() throws {
        let json = """
        {
            "version": 1,
            "rules": [
                {
                    "id": "00000000-0000-0000-0000-000000000004",
                    "host": {"kind": "equals", "value": "example.com"},
                    "action": {"kind": "block"},
                    "enabled": true
                }
            ],
            "fallback": {"kind": "ask"}
        }
        """
        let file = try decoder.decode(RulesFile.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(file.rules.count, 1)
        XCTAssertNil(file.rules[0].trackerOverrides,
                     "Legacy rules.json without trackerOverrides must decode with nil on each rule")
    }

    func test_trackerOverridesEmptyArraysRoundTrip_VAL_M4_TRACKER_RULE_004() throws {
        let overrides = TrackerOverrides(additions: [], disabled: [])
        let original = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            trackerOverrides: overrides
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DomainRule.self, from: data)
        XCTAssertEqual(decoded.trackerOverrides?.additions, [])
        XCTAssertEqual(decoded.trackerOverrides?.disabled, [])
    }
}
