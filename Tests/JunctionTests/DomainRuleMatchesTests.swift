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

    // MARK: - first-match-wins ordering (contract drag-to-reorder relies on)

    /// Two rules that both match the same URL must resolve to the **first**
    /// rule in the list. Reordering the array therefore changes routing —
    /// which is exactly what the Rules tab's drag handles depend on.
    func test_firstMatchingRuleWins_inOrder() {
        let specific = DomainRule(host: .equals("api.github.com"), action: .block)
        let broad    = DomainRule(host: .suffix("github.com"), action: .ask)
        let u = url("https://api.github.com/v3/users")

        let specificFirst = [specific, broad]
        let firstHit = specificFirst.first {
            $0.matches(url: u, host: "api.github.com", context: emptyContext)
        }
        XCTAssertEqual(firstHit?.action, .block)

        let broadFirst = [broad, specific]
        let secondHit = broadFirst.first {
            $0.matches(url: u, host: "api.github.com", context: emptyContext)
        }
        XCTAssertEqual(secondHit?.action, .ask)
    }

    // MARK: - urlEquals (exact URL match)

    private func exactRule(_ target: String, action: RuleAction = .block) -> DomainRule {
        // `host` is required by the model but ignored by the matcher when
        // `urlEquals` is set; seed it with whatever the URL's host is so
        // the display layer has something sensible.
        let parsed = URL(string: target)
        return DomainRule(
            host: .equals(parsed?.host ?? ""),
            action: action,
            urlEquals: target
        )
    }

    func test_urlEquals_matchesExactURL() {
        let rule = exactRule("https://example.com/foo")
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_doesNotMatchDifferentPath() {
        let rule = exactRule("https://example.com/foo")
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/bar"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_doesNotMatchAnyExtraQuery() {
        let rule = exactRule("https://example.com/foo")
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/foo?x=1"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_schemeAndHostCaseInsensitive() {
        let rule = exactRule("https://example.com/foo")
        // RFC says scheme and authority are case-insensitive.
        XCTAssertTrue(rule.matches(
            url: url("HTTPS://EXAMPLE.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_pathRemainsCaseSensitive() {
        // Servers differ on path case-folding; we stay strict so users
        // can't be surprised by a "match" that fails server-side.
        let rule = exactRule("https://example.com/foo")
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/Foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_stripsDefaultPort() {
        let rule = exactRule("https://example.com/foo")
        XCTAssertTrue(rule.matches(
            url: url("https://example.com:443/foo"),
            host: "example.com",
            context: emptyContext
        ))
        let httpRule = exactRule("http://example.com/foo")
        XCTAssertTrue(httpRule.matches(
            url: url("http://example.com:80/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_keepsNonDefaultPort() {
        let rule = exactRule("https://example.com:8443/foo")
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
        XCTAssertTrue(rule.matches(
            url: url("https://example.com:8443/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_stripsFragment() {
        let rule = exactRule("https://example.com/foo")
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/foo#section-2"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_treatsRootSlashAndEmptyPathAsEqual() {
        let rule = exactRule("https://example.com")
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_shortCircuitsHostAndPathConstraints() {
        // A urlEquals rule with a host filter that *should* exclude the URL
        // must still match — urlEquals is the source of truth and the
        // other constraint fields are ignored when it is set.
        let rule = DomainRule(
            host: .equals("not-the-real-host.example.org"),
            action: .block,
            schemes: ["mailto"],
            path: .prefix("/never-this-path"),
            queryContains: "never-this-query",
            urlEquals: "https://example.com/foo"
        )
        XCTAssertTrue(rule.matches(
            url: url("https://example.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_disabledRuleStillSkipped() {
        var rule = exactRule("https://example.com/foo")
        rule.enabled = false
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    func test_urlEquals_invalidTargetNeverMatches() {
        // Garbage target string shouldn't crash the matcher or accidentally
        // match anything — it just becomes a dead rule.
        let rule = exactRule("not a real url")
        XCTAssertFalse(rule.matches(
            url: url("https://example.com/foo"),
            host: "example.com",
            context: emptyContext
        ))
    }

    // MARK: - display + dedup helpers used by the Rules tab + agent

    func test_kindLabel_urlForExactRule_andHostKindOtherwise() {
        XCTAssertEqual(exactRule("https://example.com/foo").kindLabel, "url")
        XCTAssertEqual(DomainRule(host: .suffix("example.com"), action: .ask).kindLabel, "suffix")
    }

    func test_displayValue_fullURLForExactRule() {
        XCTAssertEqual(
            exactRule("https://example.com/foo").displayValue,
            "https://example.com/foo"
        )
    }

    func test_dedupKey_urlAndHostKindsNeverCollide() {
        // A urlEquals rule and a host rule that happen to share the host
        // string must not dedupe against each other — they're different
        // kinds of rule with different match semantics.
        let urlRule  = exactRule("https://example.com/foo")
        let hostRule = DomainRule(host: .equals("example.com"), action: .ask)
        XCTAssertNotEqual(urlRule.dedupKey, hostRule.dedupKey)
    }
}
