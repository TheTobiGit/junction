import XCTest
@testable import JunctionApp

final class RuleConflictDetectorTests: XCTestCase {

    private func action() -> RuleAction { .ask }

    private func rule(
        host: HostMatch,
        path: URLPathMatch? = nil,
        when: RuleCondition? = nil,
        schemes: [String]? = nil,
        urlEquals: String? = nil,
        enabled: Bool = true
    ) -> DomainRule {
        DomainRule(
            host: host,
            action: action(),
            enabled: enabled,
            when: when,
            schemes: schemes,
            path: path,
            urlEquals: urlEquals
        )
    }

    // VAL-M2-CONFLICT-001: Two rules with the same HostMatch and no disambiguators —
    // the second is detected as shadowed by the first.
    func test_identicalHosts_secondIsShadowed_VAL_M2_CONFLICT_001() {
        let r1 = rule(host: .suffix("github.com"))
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r1.id))
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // VAL-M2-CONFLICT-002: Same host, earlier with path: .prefix("/foo"), later with
    // path: .prefix("/bar") — neither is flagged.
    func test_disjointPathPrefixes_neitherFlagged_VAL_M2_CONFLICT_002() {
        let r1 = rule(host: .suffix("github.com"), path: .prefix("/foo"))
        let r2 = rule(host: .suffix("github.com"), path: .prefix("/bar"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.isEmpty)
    }

    // VAL-M2-CONFLICT-003: Earlier host: .suffix("github.com") path == nil;
    // later same host with path: .prefix("/orgs") — later is flagged.
    func test_earlierNilPathShadowsLaterWithPath_VAL_M2_CONFLICT_003() {
        let r1 = rule(host: .suffix("github.com"))
        let r2 = rule(host: .suffix("github.com"), path: .prefix("/orgs"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r1.id))
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // VAL-M2-CONFLICT-004: Earlier host: .equals("api.github.com"), later
    // host: .suffix("github.com") — later is NOT flagged.
    func test_hostKindDivergence_neitherFlagged_VAL_M2_CONFLICT_004() {
        let r1 = rule(host: .equals("api.github.com"))
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.isEmpty)
    }

    // VAL-M2-CONFLICT-005: Earlier rule with when.sourceApp == [Slack], later
    // same-host rule with when == nil — later is NOT flagged.
    func test_sourceAppConditionDisambiguates_laterNotFlagged_VAL_M2_CONFLICT_005() {
        let r1 = rule(host: .suffix("github.com"), when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]))
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r2.id))
    }

    // VAL-M2-CONFLICT-006: Two rules with same host and identical when.sourceApp
    // arrays — second is flagged.
    func test_identicalSourceApp_secondIsShadowed_VAL_M2_CONFLICT_006() {
        let condition = RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        let r1 = rule(host: .suffix("github.com"), when: condition)
        let r2 = rule(host: .suffix("github.com"), when: condition)
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r1.id))
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // VAL-M2-CONFLICT-007: Earlier restricted to schemes: ["https"], later same-host
    // restricted to schemes: ["http"] — later is NOT flagged.
    func test_schemeDivergence_laterNotFlagged_VAL_M2_CONFLICT_007() {
        let r1 = rule(host: .suffix("github.com"), schemes: ["https"])
        let r2 = rule(host: .suffix("github.com"), schemes: ["http"])
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.isEmpty)
    }

    // VAL-M2-CONFLICT-008: Earlier rule with enabled == false covers same host as
    // later enabled rule — later is NOT flagged.
    func test_disabledEarlierRule_doesNotShadow_VAL_M2_CONFLICT_008() {
        let r1 = rule(host: .suffix("github.com"), enabled: false)
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r2.id))
    }

    // VAL-M2-CONFLICT-009: Two rules with same urlEquals value and same when —
    // second is flagged.
    func test_identicalUrlEquals_secondIsShadowed_VAL_M2_CONFLICT_009() {
        let r1 = rule(host: .equals("github.com"), urlEquals: "https://github.com/orgs/acme")
        let r2 = rule(host: .equals("github.com"), urlEquals: "https://github.com/orgs/acme")
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r1.id))
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // VAL-CROSS-004 (part 1): [ruleA(sourceApp=Slack), ruleB(no sourceApp)] for same
    // host — conflict pass does NOT mark ruleB as shadowed.
    func test_sourceAppFirst_unconstrainedSecond_notShadowed_VAL_CROSS_004a() {
        let rA = rule(host: .suffix("github.com"), when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]))
        let rB = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [rA, rB])
        XCTAssertFalse(shadowed.contains(rB.id))
    }

    // VAL-CROSS-004 (part 2): Reversed order — ruleA IS shadowed because unconstrained
    // earlier rule subsumes the Slack-conditioned one.
    func test_unconstrainedFirst_sourceAppSecond_secondIsShadowed_VAL_CROSS_004b() {
        let rB = rule(host: .suffix("github.com"))
        let rA = rule(host: .suffix("github.com"), when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"]))
        let shadowed = RuleConflictDetector.shadowed(rules: [rB, rA])
        XCTAssertTrue(shadowed.contains(rA.id))
    }

    // Additional: suffix covers equals for same apex host
    func test_suffixCoversEqualsApex() {
        let r1 = rule(host: .suffix("github.com"))
        let r2 = rule(host: .equals("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // Additional: suffix covers equals for subdomain
    func test_suffixCoversEqualsSubdomain() {
        let r1 = rule(host: .suffix("github.com"))
        let r2 = rule(host: .equals("api.github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // Additional: equals does NOT cover suffix
    func test_equalsDoesNotCoverSuffix() {
        let r1 = rule(host: .equals("github.com"))
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r2.id))
    }

    // Additional: earlier rule with path does NOT shadow later rule without path
    func test_earlierWithPath_doesNotShadowLaterWithoutPath() {
        let r1 = rule(host: .suffix("github.com"), path: .prefix("/orgs"))
        let r2 = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r2.id))
    }

    // Additional: different urlEquals values — neither shadowed
    func test_differentUrlEquals_neitherShadowed() {
        let r1 = rule(host: .equals("github.com"), urlEquals: "https://github.com/foo")
        let r2 = rule(host: .equals("github.com"), urlEquals: "https://github.com/bar")
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.isEmpty)
    }

    // Additional: nil urlEquals earlier covers specific urlEquals later
    func test_nilUrlEqualsEarlier_coversSpecificUrlEqualsLater() {
        let r1 = rule(host: .equals("github.com"))
        let r2 = rule(host: .equals("github.com"), urlEquals: "https://github.com/foo")
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // Additional: specific urlEquals earlier does NOT cover nil urlEquals later
    func test_specificUrlEqualsEarlier_doesNotCoverNilUrlEqualsLater() {
        let r1 = rule(host: .equals("github.com"), urlEquals: "https://github.com/foo")
        let r2 = rule(host: .equals("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertFalse(shadowed.contains(r2.id))
    }

    // Additional: schemes superset covers subset
    func test_schemeSupersetCoversSubset() {
        let r1 = rule(host: .suffix("github.com"), schemes: ["http", "https"])
        let r2 = rule(host: .suffix("github.com"), schemes: ["https"])
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // Additional: nil schemes earlier covers restricted schemes later
    func test_nilSchemesEarlier_coversRestrictedSchemesLater() {
        let r1 = rule(host: .suffix("github.com"))
        let r2 = rule(host: .suffix("github.com"), schemes: ["https"])
        let shadowed = RuleConflictDetector.shadowed(rules: [r1, r2])
        XCTAssertTrue(shadowed.contains(r2.id))
    }

    // Additional: empty rules list returns empty set
    func test_emptyRules_returnsEmptySet() {
        let shadowed = RuleConflictDetector.shadowed(rules: [])
        XCTAssertTrue(shadowed.isEmpty)
    }

    // Additional: single rule is never shadowed
    func test_singleRule_neverShadowed() {
        let r = rule(host: .suffix("github.com"))
        let shadowed = RuleConflictDetector.shadowed(rules: [r])
        XCTAssertTrue(shadowed.isEmpty)
    }
}
