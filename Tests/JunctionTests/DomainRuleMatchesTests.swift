import XCTest
@testable import JunctionApp

/// Locks down `DomainRule.matches(url:host:context:)` — the single matcher
/// every callsite now uses (the old `RulesStore.match(host:)` was deleted
/// because it silently skipped any rule with `schemes`, `path`, or
/// `queryContains` set). Anything the upcoming add-rule UI lets a user enter
/// must be enforced here, so these tests double as the spec.
final class DomainRuleMatchesTests: XCTestCase {

    // MARK: - Fixtures

    private let emptyContext = RouteContext(
        source: nil,
        focus: FocusInfo(modeIdentifier: nil, modeName: nil)
    )

    private func context(sourceBundleID: String? = nil, focusMode: String? = nil) -> RouteContext {
        let source = sourceBundleID.map { URLSource(bundleID: $0, name: $0, icon: nil) }
        return RouteContext(
            source: source,
            focus: FocusInfo(modeIdentifier: focusMode, modeName: focusMode)
        )
    }

    private func url(_ string: String) -> URL {
        guard let u = URL(string: string) else {
            preconditionFailure("test fixture: invalid URL \(string)")
        }
        return u
    }

    // MARK: - Bare host rule (no constraints)

    func test_bareSuffixRule_matchesApex() {
        let rule = DomainRule(host: .suffix("example.com"), action: .ask)
        let u = url("https://example.com/")
        XCTAssertTrue(rule.matches(url: u, host: "example.com", context: emptyContext))
    }

    func test_bareSuffixRule_matchesSubdomain() {
        let rule = DomainRule(host: .suffix("example.com"), action: .ask)
        let u = url("https://docs.example.com/x")
        XCTAssertTrue(rule.matches(url: u, host: "docs.example.com", context: emptyContext))
    }

    func test_bareEqualsRule_doesNotMatchSubdomain() {
        let rule = DomainRule(host: .equals("example.com"), action: .ask)
        let u = url("https://docs.example.com/")
        XCTAssertFalse(rule.matches(url: u, host: "docs.example.com", context: emptyContext))
    }

    // MARK: - Path constraint (the regression the old host matcher hid)

    func test_pathPrefix_filtersByPath() {
        let rule = DomainRule(
            host: .suffix("github.com"),
            action: .ask,
            path: .prefix("/orgs/")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://github.com/orgs/acme"),
            host: "github.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://github.com/acme/repo"),
            host: "github.com",
            context: emptyContext
        ))
    }

    func test_pathGlob_escapesRegexMetachars() {
        // The glob compiler escapes `.` so `*.swift` doesn't match `axswift`.
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            path: .glob("/files/*.swift")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/files/main.swift"),
            host: "example.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/files/mainxswift"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_pathRegex_appliesToPathOnly() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            path: .regex("^/v[0-9]+/")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/v2/users"),
            host: "example.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/api/v2/users"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_pathContains_matchesAnywhere() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            path: .contains("/draft/")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/docs/draft/intro"),
            host: "example.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/docs/intro"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_pathDefaultsToSlash_whenURLHasEmptyPath() {
        // URL("https://example.com") reports an empty path; matcher should
        // treat it as "/" so a `prefix("/")` rule isn't silently skipped.
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            path: .prefix("/")
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com"),
            host: "example.com",
            context: emptyContext
        ))
    }

    // MARK: - queryContains

    func test_queryContains_caseInsensitive() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            queryContains: "utm_source"
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/x?UTM_SOURCE=email"),
            host: "example.com",
            context: emptyContext
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/x?ref=email"),
            host: "example.com",
            context: emptyContext
        ))
    }

    // MARK: - schemes (non-web)

    func test_schemesAllowsNonWebScheme_withoutHost() {
        // `slack:` URLs have no host; the matcher should still pass when the
        // rule explicitly opts in via `schemes`. This is the surface that
        // makes "open all slack: links in the Slack app" rules possible.
        let rule = DomainRule(
            host: .equals(""),
            action: .appScheme("slack"),
            schemes: ["slack"]
        )
        XCTAssertTrue(rule.matches(
            url: url("slack://channel?team=T01&id=C01"),
            host: nil,
            context: emptyContext
        ))
    }

    func test_schemes_rejectsMismatchedScheme() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            schemes: ["https"]
        )
        XCTAssertFalse(rule.matches(
            url: url("http://example.com/"),
            host: "example.com",
            context: emptyContext
        ))
    }

    // MARK: - when (source app / focus)

    func test_whenSourceApp_requiresMatchingBundle() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            when: RuleCondition(sourceApp: ["com.tinyspeck.slackmacgap"])
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: context(sourceBundleID: "com.tinyspeck.slackmacgap")
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: context(sourceBundleID: "com.apple.mail")
        ))
    }

    func test_whenFocus_substringMatch() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            when: RuleCondition(focus: ["work"])
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: context(focusMode: "com.apple.donotdisturb.mode.work")
        ))
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: context(focusMode: "com.apple.donotdisturb.mode.personal")
        ))
    }

    // MARK: - enabled flag

    func test_disabledRule_neverMatches() {
        let rule = DomainRule(
            host: .suffix("example.com"),
            action: .ask,
            enabled: false
        )
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: emptyContext
        ))
    }

    // MARK: - scheme defaults (web-only when `schemes` is unset)

    func test_unsetSchemes_requiresResolvedHostOrWebScheme() {
        let rule = DomainRule(host: .suffix("example.com"), action: .ask)
        // A hostless non-web URL with no `schemes` opt-in must not match.
        XCTAssertFalse(rule.matches(
            url: url("slack://example.com"),
            host: nil,
            context: emptyContext
        ))
    }
}
