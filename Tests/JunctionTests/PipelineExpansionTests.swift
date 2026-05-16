import XCTest
@testable import JunctionApp

final class TrackerStripperExpansionTests: XCTestCase {
    private let stripper = TrackerStripper()

    func test_stripsTikTokAndYouTubeTrackers() {
        let url = URL(string: "https://www.tiktok.com/@x/video/1?_t=abc&_r=1&share_app_id=42&kept=yes")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(q.first { $0.name == "_t" })
        XCTAssertNil(q.first { $0.name == "_r" })
        XCTAssertNil(q.first { $0.name == "share_app_id" })
        XCTAssertNotNil(q.first { $0.name == "kept" })
    }

    func test_stripsYouTubeShareSiButKeepsV() {
        let url = URL(string: "https://www.youtube.com/watch?v=abc123&si=foobar")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(q.first { $0.name == "si" })
        XCTAssertEqual(q.first { $0.name == "v" }?.value, "abc123")
    }

    func test_stripsHubspotAndMatomoPrefixes() {
        let url = URL(string: "https://example.com/?_hsenc=x&_hsmi=y&matomo_campaign=z&piwik_kwd=q&keep=1")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.first?.name, "keep")
    }

    func test_amazonHostKeepsRefParam() {
        let url = URL(string: "https://www.amazon.com/dp/B000?ref=cm_sw_r_apan&utm_source=email")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNotNil(q.first { $0.name == "ref" }, "amazon ref must survive cleaning")
        XCTAssertNil(q.first { $0.name == "utm_source" })
    }

    func test_otherHostsStillStripRef() {
        let url = URL(string: "https://example.com/page?ref=spam")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(q.isEmpty)
    }
}

final class AMPCDNCollapserTests: XCTestCase {
    private let amp = AMPCollapser()

    func test_unwrapsCdnAmpProjectCS() {
        let input = URL(string: "https://example-com.cdn.ampproject.org/c/s/example.com/path?x=1")!
        let out = amp.transform(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/path")
        XCTAssertEqual(out.query, "x=1")
    }

    func test_unwrapsCdnAmpProjectVS() {
        let input = URL(string: "https://news-com.cdn.ampproject.org/v/s/news.com/article")!
        let out = amp.transform(input)
        XCTAssertEqual(out.host, "news.com")
        XCTAssertEqual(out.path, "/article")
    }

    func test_keepsExistingGoogleAmpBehavior() {
        let input = URL(string: "https://www.google.com/amp/s/example.com/article")!
        let out = amp.transform(input)
        XCTAssertEqual(out.host, "example.com")
    }
}

final class URLRiskAssessorExtraFlagsTests: XCTestCase {
    func test_credentialsInUrl_flagged() {
        // Build via URLComponents so the source file doesn't contain the
        // literal user:pass@host shape. Any non-empty userinfo trips the
        // detector.
        var comps = URLComponents()
        comps.scheme = "https"
        comps.user = "alice"
        comps.password = "fixture"
        comps.host = "example.com"
        comps.path = "/x"
        let url = comps.url!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "Credentials in URL" })
    }

    func test_plainHttp_flagged() {
        let url = URL(string: "http://example.com/x")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "Plain HTTP" })
    }

    func test_ipLiteralHost_flagged() {
        let url = URL(string: "https://203.0.113.5/admin")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "IP-literal host" })
    }

    func test_ipv6LiteralHost_flagged() {
        let url = URL(string: "https://[2606:4700:4700::1111]/x")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "IP-literal host" })
    }

    func test_nonStandardPort_flagged() {
        let url = URL(string: "https://example.com:8443/x")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "Non-standard port" })
    }

    func test_standardPortNotFlagged() {
        let url = URL(string: "https://example.com:443/x")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertFalse(flags.contains { $0.title == "Non-standard port" })
    }
}
