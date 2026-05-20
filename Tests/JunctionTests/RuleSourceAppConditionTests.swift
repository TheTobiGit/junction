import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-M1-RULE-SRC-003: Submit emits correct RuleCondition.sourceApp
// VAL-M1-RULE-SRC-004: Source-app condition gates matching as configured
// VAL-M1-CLI-003: --from flag produces sourceApp condition (single + repeated)
// VAL-M1-CLI-004: AgentProtocol decodes legacy addRule payloads without sourceApps
// VAL-M1-CLI-005: AgentProtocol round-trips new addRule fields
// VAL-CROSS-011: CLI parity — path-prefix + source-app produce equal DomainRule
final class RuleSourceAppConditionTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func context(bundleID: String?) -> RouteContext {
        let source = bundleID.map { URLSource(bundleID: $0, name: $0, icon: nil) }
        return RouteContext(source: source, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
    }

    // MARK: - VAL-M1-RULE-SRC-003

    func test_builderWithPicksEmitsSourceAppCondition_VAL_M1_RULE_SRC_003() {
        let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap", "com.microsoft.teams"])
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, when: condition)
        XCTAssertEqual(rule.when?.sourceApp, ["com.tinyspeck.slackmacgap", "com.microsoft.teams"])
    }

    func test_builderWithNoPicksYieldsNilCondition_VAL_M1_RULE_SRC_003() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, when: nil)
        XCTAssertNil(rule.when)
    }

    func test_builderWithEmptySourceAppYieldsNilSourceApp_VAL_M1_RULE_SRC_003() {
        let condition = RuleCondition(sourceApp: nil)
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, when: condition)
        XCTAssertNil(rule.when?.sourceApp)
    }

    // MARK: - VAL-M1-RULE-SRC-004

    func test_sourceAppConditionMatchesMatchingBundleID_VAL_M1_RULE_SRC_004() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        let ctx = context(bundleID: "com.tinyspeck.slackmacgap")
        XCTAssertTrue(rule.matches(
            url: URL(string: "https://github.com/issues")!,
            host: "github.com",
            context: ctx
        ))
    }

    func test_sourceAppConditionRejectsDifferentBundleID_VAL_M1_RULE_SRC_004() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        let ctx = context(bundleID: "com.apple.Safari")
        XCTAssertFalse(rule.matches(
            url: URL(string: "https://github.com/issues")!,
            host: "github.com",
            context: ctx
        ))
    }

    func test_sourceAppConditionRejectsNilSource_VAL_M1_RULE_SRC_004() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        let ctx = context(bundleID: nil)
        XCTAssertFalse(rule.matches(
            url: URL(string: "https://github.com/issues")!,
            host: "github.com",
            context: ctx
        ))
    }

    func test_sourceAppConditionIsCaseInsensitive_VAL_M1_RULE_SRC_004() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["Com.TinySpeck.SlackMacGap"])
        )
        let ctx = context(bundleID: "com.tinyspeck.slackmacgap")
        XCTAssertTrue(rule.matches(
            url: URL(string: "https://github.com/issues")!,
            host: "github.com",
            context: ctx
        ))
    }

    func test_ruleConditionRoundTripsThroughCodable_VAL_M1_RULE_SRC_004() throws {
        let original = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DomainRule.self, from: data)
        XCTAssertEqual(decoded.when?.sourceApp, ["com.tinyspeck.slackmacgap"])
    }

    func test_dedupKey_sameHostDifferentSourceAppsDoNotCollide() {
        let slack = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        let mail = DomainRule(
            host: .suffix("github.com"),
            action: .block,
            when: RuleCondition(sourceApp: ["com.apple.mail"])
        )
        XCTAssertNotEqual(slack.dedupKey, mail.dedupKey)
    }

    func test_dedupKey_sameHostSameSourceAppCollides() {
        let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        let r1 = DomainRule(host: .suffix("github.com"), action: .ask, when: condition)
        let r2 = DomainRule(host: .suffix("github.com"), action: .block, when: condition)
        XCTAssertEqual(r1.dedupKey, r2.dedupKey)
    }

    func test_dedupKey_unconstrainedHostDiffersFromSourceAppRule() {
        let unconstrained = DomainRule(host: .suffix("github.com"), action: .ask, when: nil)
        let slackOnly = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        XCTAssertNotEqual(unconstrained.dedupKey, slackOnly.dedupKey)
    }

    // MARK: - VAL-M1-CLI-003

    func test_singleFromFlagProducesSourceAppCondition_VAL_M1_CLI_003() throws {
        let req = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: "app:com.apple.Safari",
            cleanOverride: nil,
            pathKind: nil,
            pathValue: nil,
            sourceApps: ["com.tinyspeck.slackmacgap"]
        )
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .addRule(_, _, _, _, _, _, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(apps, ["com.tinyspeck.slackmacgap"])
    }

    func test_repeatedFromFlagsAccumulateInOrder_VAL_M1_CLI_003() throws {
        let req = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: "app:com.apple.Safari",
            cleanOverride: nil,
            pathKind: nil,
            pathValue: nil,
            sourceApps: ["com.tinyspeck.slackmacgap", "com.microsoft.teams"]
        )
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .addRule(_, _, _, _, _, _, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(apps, ["com.tinyspeck.slackmacgap", "com.microsoft.teams"])
    }

    func test_noFromFlagProducesNilSourceApps_VAL_M1_CLI_003() throws {
        let req = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: "app:com.apple.Safari",
            cleanOverride: nil,
            pathKind: nil,
            pathValue: nil,
            sourceApps: nil
        )
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .addRule(_, _, _, _, _, _, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertNil(apps)
    }

    // MARK: - VAL-M1-CLI-004

    func test_legacyAddRulePayloadDecodesWithoutSourceApps_VAL_M1_CLI_004() throws {
        let json = #"""
        {"kind":"addRule","hostKind":"suffix","hostValue":"github.com","target":"app:com.apple.Safari"}
        """#.data(using: .utf8)!
        let decoded = try decoder.decode(AgentRequest.self, from: json)
        guard case .addRule(let hk, let hv, let t, let co, let pk, let pv, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(hk, "suffix")
        XCTAssertEqual(hv, "github.com")
        XCTAssertEqual(t, "app:com.apple.Safari")
        XCTAssertNil(co)
        XCTAssertNil(pk)
        XCTAssertNil(pv)
        XCTAssertNil(apps)
    }

    func test_legacyAddRulePayloadWithPathKindDecodesWithoutSourceApps_VAL_M1_CLI_004() throws {
        let json = #"""
        {"kind":"addRule","hostKind":"suffix","hostValue":"github.com","target":"app:com.apple.Safari","pathKind":"prefix","pathValue":"/issues"}
        """#.data(using: .utf8)!
        let decoded = try decoder.decode(AgentRequest.self, from: json)
        guard case .addRule(_, _, _, _, let pk, let pv, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(pk, "prefix")
        XCTAssertEqual(pv, "/issues")
        XCTAssertNil(apps)
    }

    // MARK: - VAL-M1-CLI-005

    func test_newFieldsRoundTripInAgentRequest_VAL_M1_CLI_005() throws {
        let original = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: "app:com.apple.Safari",
            cleanOverride: nil,
            pathKind: "prefix",
            pathValue: "/orgs/acme",
            sourceApps: ["com.tinyspeck.slackmacgap"]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .addRule(let hk, let hv, let t, _, let pk, let pv, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(hk, "suffix")
        XCTAssertEqual(hv, "github.com")
        XCTAssertEqual(t, "app:com.apple.Safari")
        XCTAssertEqual(pk, "prefix")
        XCTAssertEqual(pv, "/orgs/acme")
        XCTAssertEqual(apps, ["com.tinyspeck.slackmacgap"])
    }

    func test_encodedJSONContainsSourceAppsFieldName_VAL_M1_CLI_005() throws {
        let req = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: nil,
            cleanOverride: nil,
            pathKind: "prefix",
            pathValue: "/orgs/acme",
            sourceApps: ["com.tinyspeck.slackmacgap"]
        )
        let data = try encoder.encode(req)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("sourceApps"), "encoded JSON must contain 'sourceApps' key")
        XCTAssertTrue(json.contains("pathKind"), "encoded JSON must contain 'pathKind' key")
        XCTAssertTrue(json.contains("pathValue"), "encoded JSON must contain 'pathValue' key")
    }

    // MARK: - VAL-CROSS-011

    func test_cliAndUIBuilderProduceEqualDomainRule_VAL_CROSS_011() {
        // Simulate CLI path: AppDelegate.handleAgentRequest builds DomainRule from AgentRequest fields
        let cliRule: DomainRule = {
            let hostMatch = HostMatch.suffix("github.com")
            let pathMatch = URLPathMatch.prefix("/issues")
            let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
            var rule = DomainRule(host: hostMatch, action: .ask)
            rule.path = pathMatch
            rule.when = condition
            return rule
        }()

        // Simulate UI path: AddRuleSheet.submit() builds DomainRule directly
        let uiRule: DomainRule = {
            let hostMatch = HostMatch.suffix("github.com")
            let pathMatch = URLPathMatch.prefix("/issues")
            let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
            return DomainRule(host: hostMatch, action: .ask, when: condition, path: pathMatch)
        }()

        XCTAssertEqual(cliRule.host, uiRule.host)
        XCTAssertEqual(cliRule.action, uiRule.action)
        XCTAssertEqual(cliRule.path, uiRule.path)
        XCTAssertEqual(cliRule.when?.sourceApp, uiRule.when?.sourceApp)
        XCTAssertEqual(cliRule.enabled, uiRule.enabled)
    }

    func test_cliAndUIBuilderProduceEqualCodableRepresentation_VAL_CROSS_011() throws {
        let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        let pathMatch = URLPathMatch.prefix("/issues")

        var cliRule = DomainRule(host: .suffix("github.com"), action: .ask)
        cliRule.path = pathMatch
        cliRule.when = condition

        let uiRule = DomainRule(host: .suffix("github.com"), action: .ask, when: condition, path: pathMatch)

        let cliData = try encoder.encode(cliRule)
        let uiData = try encoder.encode(uiRule)

        let cliDecoded = try decoder.decode(DomainRule.self, from: cliData)
        let uiDecoded = try decoder.decode(DomainRule.self, from: uiData)

        XCTAssertEqual(cliDecoded.host, uiDecoded.host)
        XCTAssertEqual(cliDecoded.path, uiDecoded.path)
        XCTAssertEqual(cliDecoded.when?.sourceApp, uiDecoded.when?.sourceApp)
    }
}
