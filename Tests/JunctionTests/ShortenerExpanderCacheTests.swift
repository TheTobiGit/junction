import XCTest
@testable import JunctionApp

final class ShortenerExpanderCacheTests: XCTestCase {

    // VAL-M4-SHORTENER-001: Two consecutive expand calls issue exactly one network request;
    // both return the same expanded URL.
    func test_secondCallWithinSessionIsACacheHit_VAL_M4_SHORTENER_001() {
        var requestCount = 0
        let expanded = URL(string: "https://example.com/article")!
        let expander = ShortenerExpander { _, _, completion in
            requestCount += 1
            completion(expanded)
        }

        let shortURL = URL(string: "https://t.co/abc")!

        let exp1 = expectation(description: "first expand")
        var result1: URL?
        expander.expand(shortURL) { url in
            result1 = url
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1.0)

        let exp2 = expectation(description: "second expand")
        var result2: URL?
        expander.expand(shortURL) { url in
            result2 = url
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)

        XCTAssertEqual(requestCount, 1, "second call must be a cache hit — no additional network request")
        XCTAssertEqual(result1, expanded)
        XCTAssertEqual(result2, expanded)
    }

    // VAL-M4-SHORTENER-002: A fresh ShortenerExpander after a first instance populated its
    // cache issues a network request for the same shortener URL.
    func test_freshInstanceIssuesNewNetworkRequest_VAL_M4_SHORTENER_002() {
        var requestCount = 0
        let expanded = URL(string: "https://example.com/article")!
        let networkExpand: (URL, TimeInterval, @escaping (URL) -> Void) -> Void = { _, _, completion in
            requestCount += 1
            completion(expanded)
        }

        let shortURL = URL(string: "https://t.co/abc")!

        let expander1 = ShortenerExpander(networkExpand: networkExpand)
        let exp1 = expectation(description: "first instance expand")
        expander1.expand(shortURL) { _ in exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)

        XCTAssertEqual(requestCount, 1)

        let expander2 = ShortenerExpander(networkExpand: networkExpand)
        let exp2 = expectation(description: "second instance expand — fresh cache")
        expander2.expand(shortURL) { _ in exp2.fulfill() }
        wait(for: [exp2], timeout: 1.0)

        XCTAssertEqual(requestCount, 2, "fresh instance must not share cache with first instance")
    }

    // VAL-M4-SHORTENER-003: A cached expansion that resolves to a non-publicly-routable host
    // is rejected by URLSafety.isPubliclyRoutable and not returned.
    func test_ssrfGuardAppliesToCachedValues_VAL_M4_SHORTENER_003() {
        let expander = ShortenerExpander { _, _, completion in
            completion(URL(string: "https://example.com")!)
        }

        let shortURL = URL(string: "https://t.co/abc")!
        let privateURL = URL(string: "http://127.0.0.1/evil")!
        expander.seedCache(shortURL, resolvedTo: privateURL)

        let exp = expectation(description: "expand with seeded private-IP cache entry")
        var result: URL?
        expander.expand(shortURL) { url in
            result = url
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertNotEqual(result, privateURL, "SSRF guard must reject private-IP cached value")
        XCTAssertEqual(result, shortURL, "must fall back to original shortener URL when cached target is non-routable")
    }

    // VAL-M4-SHORTENER-004: Calling expand on a non-shortener URL does not insert an entry
    // into the per-session cache; cache size remains 0.
    func test_nonShortenerURLDoesNotPopulateCache_VAL_M4_SHORTENER_004() {
        var requestCount = 0
        let expander = ShortenerExpander { _, _, completion in
            requestCount += 1
            completion(URL(string: "https://example.com/article")!)
        }

        let nonShortURL = URL(string: "https://example.com/article")!
        let exp = expectation(description: "expand non-shortener URL")
        expander.expand(nonShortURL) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(expander.cacheSize, 0, "non-shortener URL must not populate the cache")
        XCTAssertEqual(requestCount, 0, "non-shortener URL must not trigger a network request")
    }
}
