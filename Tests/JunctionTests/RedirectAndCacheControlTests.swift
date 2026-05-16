import XCTest
@testable import JunctionApp

final class DomainRedirectPathTemplateTests: XCTestCase {
    func test_hostOnlyRedirectPreservesPathAndQuery() {
        let redirect = DomainRedirect(fromHost: "twitter.com", toHost: "nitter.net")
        let input = URL(string: "https://twitter.com/user/status/123?lang=en#frag")!
        let out = redirect.apply(to: input)
        XCTAssertEqual(out?.host, "nitter.net")
        XCTAssertEqual(out?.path, "/user/status/123")
        XCTAssertEqual(out?.query, "lang=en")
        XCTAssertEqual(out?.fragment, "frag")
    }

    func test_pathTemplateRewritesPath() {
        let redirect = DomainRedirect(
            fromHost: "medium.com",
            toHost: "freedium.cfd",
            pathTemplate: "/article{path}"
        )
        let input = URL(string: "https://medium.com/@user/title-abc123")!
        let out = redirect.apply(to: input)
        XCTAssertEqual(out?.host, "freedium.cfd")
        XCTAssertEqual(out?.path, "/article/@user/title-abc123")
    }

    func test_pathTemplateSubstitutesQuery() {
        let redirect = DomainRedirect(
            fromHost: "example.com",
            toHost: "wrapped.example.com",
            pathTemplate: "/wrap?orig={query}"
        )
        let input = URL(string: "https://example.com/x?a=1&b=2")!
        let out = redirect.apply(to: input)
        XCTAssertEqual(out?.host, "wrapped.example.com")
        XCTAssertEqual(out?.path, "/wrap")
        XCTAssertEqual(out?.query, "orig=a=1&b=2")
    }

    func test_subdomainsAlsoMatch() {
        let redirect = DomainRedirect(fromHost: "twitter.com", toHost: "nitter.net")
        let input = URL(string: "https://m.twitter.com/path")!
        XCTAssertEqual(redirect.apply(to: input)?.host, "nitter.net")
    }

    func test_decodesLegacyJSONWithoutPathTemplate() throws {
        let json = #"""
        { "id": "00000000-0000-0000-0000-000000000000",
          "fromHost": "twitter.com",
          "toHost": "nitter.net",
          "enabled": true,
          "label": "X → Nitter" }
        """#.data(using: .utf8)!
        let redirect = try JSONDecoder().decode(DomainRedirect.self, from: json)
        XCTAssertNil(redirect.pathTemplate)
        XCTAssertTrue(redirect.enabled)
    }
}

final class CacheControlPersistenceTests: XCTestCase {
    func test_allowsPersist_whenNoHeader() {
        XCTAssertTrue(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: nil))
    }

    func test_allowsPersist_forPublicPolicies() {
        XCTAssertTrue(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "public, max-age=3600"))
        XCTAssertTrue(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "max-age=600"))
    }

    func test_blocksPersist_forNoStoreOrPrivate() {
        XCTAssertFalse(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "no-store"))
        XCTAssertFalse(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "private, max-age=0"))
        XCTAssertFalse(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "Private"))
        XCTAssertFalse(LinkPreviewFetcher.allowsPersistedPreview(cacheControl: "no-cache, no-store"))
    }
}
