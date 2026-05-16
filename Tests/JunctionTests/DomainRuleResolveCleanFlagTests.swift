import XCTest
@testable import JunctionApp

final class DomainRuleResolveCleanFlagTests: XCTestCase {
    func test_overrideNilFallsBackToGlobalEnabled() {
        let rule = DomainRule(host: .equals("a.example.com"), action: .ask, cleanOverride: nil)
        XCTAssertTrue(DomainRule.resolveCleanFlag(rule: rule, globalEnabled: true))
        XCTAssertFalse(DomainRule.resolveCleanFlag(rule: rule, globalEnabled: false))
    }

    func test_overrideTrueWinsEvenWhenGlobalDisabled() {
        let rule = DomainRule(host: .equals("a.example.com"), action: .ask, cleanOverride: true)
        XCTAssertTrue(DomainRule.resolveCleanFlag(rule: rule, globalEnabled: false))
    }

    func test_overrideFalseWinsEvenWhenGlobalEnabled() {
        let rule = DomainRule(host: .equals("a.example.com"), action: .ask, cleanOverride: false)
        XCTAssertFalse(DomainRule.resolveCleanFlag(rule: rule, globalEnabled: true))
    }

    func test_nilRuleFallsBackToGlobal() {
        XCTAssertTrue(DomainRule.resolveCleanFlag(rule: nil, globalEnabled: true))
        XCTAssertFalse(DomainRule.resolveCleanFlag(rule: nil, globalEnabled: false))
    }
}
