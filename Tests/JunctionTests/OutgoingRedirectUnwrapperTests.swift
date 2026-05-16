import XCTest
@testable import JunctionApp

final class OutgoingRedirectUnwrapperTests: XCTestCase {
    private let unwrap = OutgoingRedirectUnwrapper()

    func test_facebook_l_php_unwraps_u_param() {
        let input = URL(string: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Farticle%3Fa%3D1&h=AT0xyz")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out.absoluteString, "https://example.com/article?a=1")
    }

    func test_google_url_unwraps_q_param() {
        let input = URL(string: "https://www.google.com/url?sa=t&q=https%3A%2F%2Fexample.com%2Fdoc&usg=abc")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/doc")
    }

    func test_youtube_redirect_unwraps_q() {
        let input = URL(string: "https://www.youtube.com/redirect?event=video_description&q=https%3A%2F%2Fexample.com%2Fwatch%3Fv%3D42")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/watch")
    }

    func test_unknown_host_is_passthrough() {
        let input = URL(string: "https://example.com/article?a=1")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out, input)
    }

    func test_path_prefix_required_for_google() {
        // /search?q=… is not a redirect endpoint, must remain untouched.
        let input = URL(string: "https://www.google.com/search?q=https%3A%2F%2Fexample.com")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out, input)
    }

    func test_anonym_to_uses_query_string() {
        let input = URL(string: "https://anonym.to/?https://example.com/path")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/path")
    }

    func test_chained_wrappers_unwrap_through_pipeline() {
        // l.facebook.com → google.com/url → real
        let inner = "https%3A%2F%2Fexample.com%2Ffinal"
        let middle = "https%3A%2F%2Fwww.google.com%2Furl%3Fq%3D\(inner)"
        let input = URL(string: "https://l.facebook.com/l.php?u=\(middle)")!
        let out = unwrap.transform(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/final")
    }

    func test_pipeline_runs_unwrap_then_strips_trackers() {
        let input = URL(string: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fa%3Futm_source%3Demail%26x%3D1")!
        let out = URLTransformers.default.run(input)
        XCTAssertEqual(out.host, "example.com")
        XCTAssertEqual(out.path, "/a")
        let q = URLComponents(url: out, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(q.first { $0.name == "utm_source" })
        XCTAssertNotNil(q.first { $0.name == "x" })
    }

    func test_non_http_target_is_rejected() {
        let input = URL(string: "https://l.facebook.com/l.php?u=javascript%3Aalert(1)")!
        let out = unwrap.transform(input)
        // javascript: must not surface; we keep the wrapper URL untouched.
        XCTAssertEqual(out, input)
    }
}
