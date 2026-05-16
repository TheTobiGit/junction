import XCTest
@testable import JunctionApp

final class DomainRuleCleanOverrideTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    func test_defaultCleanOverrideIsNil() {
        let rule = DomainRule(host: .equals("example.com"), action: .ask)
        XCTAssertNil(rule.cleanOverride)
    }

    func test_legacyJSONWithoutCleanOverrideDecodes() throws {
        let json = #"""
        {"id":"00000000-0000-0000-0000-000000000000","host":{"kind":"equals","value":"example.com"},"action":{"kind":"ask"},"enabled":true,"alsoCopyCleaned":false}
        """#.data(using: .utf8)!
        let rule = try decoder.decode(DomainRule.self, from: json)
        XCTAssertNil(rule.cleanOverride)
        XCTAssertEqual(rule.host.displayValue, "example.com")
    }

    func test_cleanOverrideRoundTripsThroughCodable() throws {
        let original = DomainRule(
            host: .equals("internal.example.com"),
            action: .open(.app(bundleID: "com.apple.Safari")),
            cleanOverride: false
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DomainRule.self, from: data)
        XCTAssertEqual(decoded.cleanOverride, false)
    }

    func test_explicitTrueAndFalseAreDistinguishedFromNil() throws {
        for value: Bool? in [nil, true, false] {
            let rule = DomainRule(
                host: .equals("a.example.com"),
                action: .ask,
                cleanOverride: value
            )
            let data = try encoder.encode(rule)
            let decoded = try decoder.decode(DomainRule.self, from: data)
            XCTAssertEqual(decoded.cleanOverride, value)
        }
    }
}
