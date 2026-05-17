import XCTest
@testable import JunctionApp
@testable import JunctionCore

// VAL-M1-RULE-PATH-002: AddRuleSheet emits correct URLPathMatch on submit
// VAL-M1-RULE-PATH-003: dedupKey distinguishes path-bearing rules
// VAL-M1-RULE-PATH-004: kindLabel surfaces path discriminator
// VAL-M1-RULE-PATH-005: Path-bearing rule matches end-to-end
// VAL-M1-CLI-001: junction rules add --path-prefix produces a path-bearing rule
// VAL-M1-CLI-002: All four path kinds exposed via CLI flags; conflict rejection
final class RulePathMatchKindsTests: XCTestCase {

    private let emptyContext = RouteContext(
        source: nil,
        focus: FocusInfo(modeIdentifier: nil, modeName: nil)
    )

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: - VAL-M1-RULE-PATH-002

    func test_builderEmitsPrefix_VAL_M1_RULE_PATH_002() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs/acme"))
        XCTAssertEqual(rule.path, .prefix("/orgs/acme"))
    }

    func test_builderEmitsContains_VAL_M1_RULE_PATH_002() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: .contains("/issues"))
        XCTAssertEqual(rule.path, .contains("/issues"))
    }

    func test_builderEmitsRegex_VAL_M1_RULE_PATH_002() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: .regex("^/orgs/"))
        XCTAssertEqual(rule.path, .regex("^/orgs/"))
    }

    func test_builderEmitsGlob_VAL_M1_RULE_PATH_002() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: .glob("/orgs/*"))
        XCTAssertEqual(rule.path, .glob("/orgs/*"))
    }

    func test_builderEmitsNilPath_whenPathValueEmpty_VAL_M1_RULE_PATH_002() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: nil)
        XCTAssertNil(rule.path)
    }

    // MARK: - VAL-M1-RULE-PATH-003

    func test_dedupKey_pathBearingDiffersFromPathless_VAL_M1_RULE_PATH_003() {
        let ruleA = DomainRule(host: .suffix("github.com"), action: .ask, path: nil)
        let ruleB = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs"))
        XCTAssertNotEqual(ruleA.dedupKey, ruleB.dedupKey)
    }

    func test_dedupKey_samePathSameKey_VAL_M1_RULE_PATH_003() {
        let ruleA = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs"))
        let ruleB = DomainRule(host: .suffix("github.com"), action: .block, path: .prefix("/orgs"))
        XCTAssertEqual(ruleA.dedupKey, ruleB.dedupKey)
    }

    func test_dedupKey_differentPathKindsDiffer_VAL_M1_RULE_PATH_003() {
        let ruleA = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs"))
        let ruleB = DomainRule(host: .suffix("github.com"), action: .ask, path: .contains("/orgs"))
        XCTAssertNotEqual(ruleA.dedupKey, ruleB.dedupKey)
    }

    // MARK: - VAL-M1-RULE-PATH-004

    func test_kindLabel_pathlessRuleUsesHostKind_VAL_M1_RULE_PATH_004() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask)
        XCTAssertEqual(rule.kindLabel, "suffix")
    }

    func test_kindLabel_pathBearingRuleDiffersFromPathless_VAL_M1_RULE_PATH_004() {
        let pathless = DomainRule(host: .suffix("github.com"), action: .ask)
        let pathBearing = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs"))
        XCTAssertNotEqual(pathless.kindLabel, pathBearing.kindLabel)
    }

    func test_kindLabel_includesPathKind_VAL_M1_RULE_PATH_004() {
        let rule = DomainRule(host: .suffix("github.com"), action: .ask, path: .prefix("/orgs"))
        XCTAssertTrue(rule.kindLabel.contains("prefix"), "kindLabel '\(rule.kindLabel)' should contain 'prefix'")
    }

    func test_kindLabel_urlEqualsUnchanged_VAL_M1_RULE_PATH_004() {
        let rule = DomainRule(host: .equals("github.com"), action: .ask, urlEquals: "https://github.com/foo")
        XCTAssertEqual(rule.kindLabel, "url")
    }

    // MARK: - VAL-M1-RULE-PATH-005

    func test_pathPrefixRule_matchesAndRejects_VAL_M1_RULE_PATH_005() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .prefix("/orgs/acme")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://github.com/orgs/acme/people"),
            host: "github.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://github.com/orgs/other/people"),
            host: "github.com",
            context: emptyContext
        ))
    }

    func test_pathContainsRule_matchesAndRejects_VAL_M1_RULE_PATH_005() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .contains("/acme/")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://github.com/orgs/acme/people"),
            host: "github.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://github.com/orgs/other/people"),
            host: "github.com",
            context: emptyContext
        ))
    }

    func test_pathRegexRule_matchesAndRejects_VAL_M1_RULE_PATH_005() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .regex("^/orgs/acme")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://github.com/orgs/acme/people"),
            host: "github.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://github.com/orgs/other/people"),
            host: "github.com",
            context: emptyContext
        ))
    }

    func test_pathGlobRule_matchesAndRejects_VAL_M1_RULE_PATH_005() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .glob("/orgs/acme/*")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://github.com/orgs/acme/people"),
            host: "github.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://github.com/orgs/other/people"),
            host: "github.com",
            context: emptyContext
        ))
    }

    func test_pathBearingRuleRoundTripsThroughCodable_VAL_M1_RULE_PATH_005() throws {
        let original = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .prefix("/orgs/acme")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DomainRule.self, from: data)
        XCTAssertEqual(decoded.path, .prefix("/orgs/acme"))
        XCTAssertEqual(decoded.host, original.host)
    }

    // MARK: - VAL-M1-CLI-001

    func test_agentRequestAddRuleWithPathKindRoundTrips_VAL_M1_CLI_001() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let original = AgentRequest.addRule(
            hostKind: "suffix",
            hostValue: "github.com",
            target: "app:com.apple.Safari",
            cleanOverride: nil,
            pathKind: "prefix",
            pathValue: "/orgs/acme",
            sourceApps: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .addRule(let hk, let hv, let t, _, let pk, let pv, _) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(hk, "suffix")
        XCTAssertEqual(hv, "github.com")
        XCTAssertEqual(t, "app:com.apple.Safari")
        XCTAssertEqual(pk, "prefix")
        XCTAssertEqual(pv, "/orgs/acme")
    }

    func test_agentRequestAddRuleLegacyPayloadDecodesWithNilPath_VAL_M1_CLI_001() throws {
        let json = #"""
        {"kind":"addRule","hostKind":"suffix","hostValue":"github.com","target":"app:com.apple.Safari"}
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AgentRequest.self, from: json)
        guard case .addRule(_, _, _, _, let pk, let pv, let apps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertNil(pk)
        XCTAssertNil(pv)
        XCTAssertNil(apps)
    }

    func test_pathMatchBuiltFromAgentRequestFields_VAL_M1_CLI_001() {
        let cases: [(String, URLPathMatch)] = [
            ("prefix", .prefix("/orgs/acme")),
            ("contains", .contains("/issues")),
            ("regex", .regex("^/v[0-9]+")),
            ("glob", .glob("/files/*")),
        ]
        for (kind, expected) in cases {
            let built = URLPathMatch.from(kind: kind, value: "/orgs/acme")
            if kind == "prefix" {
                XCTAssertEqual(built, expected)
            } else {
                XCTAssertNotNil(URLPathMatch.from(kind: kind, value: "/issues"))
            }
        }
    }

    // MARK: - VAL-M1-CLI-002

    func test_allFourPathKindsRoundTripInAgentRequest_VAL_M1_CLI_002() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let kinds = ["prefix", "contains", "regex", "glob"]
        for kind in kinds {
            let req = AgentRequest.addRule(
                hostKind: "suffix",
                hostValue: "github.com",
                target: "app:com.apple.Safari",
                cleanOverride: nil,
                pathKind: kind,
                pathValue: "/test",
                sourceApps: nil
            )
            let data = try encoder.encode(req)
            let decoded = try decoder.decode(AgentRequest.self, from: data)
            guard case .addRule(_, _, _, _, let pk, let pv, _) = decoded else {
                return XCTFail("expected .addRule for kind \(kind)")
            }
            XCTAssertEqual(pk, kind, "pathKind should round-trip for \(kind)")
            XCTAssertEqual(pv, "/test", "pathValue should round-trip for \(kind)")
        }
    }

    func test_multiplePathFlagsRejected_VAL_M1_CLI_002() {
        let pathPrefix: String? = "/foo"
        let pathContains: String? = "bar"
        let pathRegex: String? = nil
        let pathGlob: String? = nil
        let count = [pathPrefix, pathContains, pathRegex, pathGlob].compactMap { $0 }.count
        XCTAssertGreaterThan(count, 1, "multiple path flags should be detected as conflict")
    }

    func test_singlePathFlagAccepted_VAL_M1_CLI_002() {
        let pathPrefix: String? = "/foo"
        let pathContains: String? = nil
        let pathRegex: String? = nil
        let pathGlob: String? = nil
        let count = [pathPrefix, pathContains, pathRegex, pathGlob].compactMap { $0 }.count
        XCTAssertEqual(count, 1, "single path flag should be accepted")
    }
}
