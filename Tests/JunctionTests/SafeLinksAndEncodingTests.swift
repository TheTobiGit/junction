import XCTest
import WebKit
@testable import JunctionApp

final class SafeLinksAndEncodingTests: XCTestCase {
    private let safeLink = "https://eur06.safelinks.protection.outlook.com/?url=http%3A%2F%2Fdownload.example.com%2F%23o%3Dhttp%253A%252F%252Fapp.example.com%26t%3Dabc123&data=05%7C02%7Cme%40example.com%7C0%7CUnknown%7CTWFp%3D%3D%7C60000%7C%7C%7C&sdata=MT8D%2FgXg%2Bw%3D&reserved=0"

    func test_safelinks_unwraps_to_target_with_fragment_intact() {
        let out = OutgoingRedirectUnwrapper().transform(URL(string: safeLink)!)
        XCTAssertEqual(out.absoluteString, "http://download.example.com/#o=http%3A%2F%2Fapp.example.com&t=abc123")
    }

    func test_safelinks_other_regions_and_gov_cloud_unwrap() {
        for host in ["nam12.safelinks.protection.outlook.com", "gcc02.safelinks.protection.office365.us"] {
            let input = URL(string: "https://\(host)/?url=https%3A%2F%2Fexample.com%2Fdoc%3Fa%3D1%26b%3D2&data=x&sdata=y&reserved=0")!
            XCTAssertEqual(OutgoingRedirectUnwrapper().transform(input).absoluteString, "https://example.com/doc?a=1&b=2", host)
        }
    }

    func test_full_pipeline_opens_safelinks_target() {
        let pipeline = URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(), AMPCollapser(), TrackerStripper(),
        ])
        XCTAssertEqual(
            pipeline.run(URL(string: safeLink)!).absoluteString,
            "http://download.example.com/#o=http%3A%2F%2Fapp.example.com&t=abc123"
        )
    }

    func test_amp_collapser_leaves_non_amp_query_byte_identical() {
        let input = URL(string: "https://example.com/p?sig=ab%2Bcd%2F%3D&to=me%40x.com")!
        XCTAssertEqual(AMPCollapser().transform(input).absoluteString, input.absoluteString)
    }

    func test_amp_collapser_keeps_other_params_encoded_when_dropping_amp() {
        let input = URL(string: "https://example.com/p?amp=1&sig=ab%2Bcd")!
        XCTAssertEqual(AMPCollapser().transform(input).absoluteString, "https://example.com/p?sig=ab%2Bcd")
    }

    func test_tracker_stripper_keeps_other_params_encoded() {
        let input = URL(string: "https://example.com/p?sig=ab%2Bcd%26e&utm_source=x")!
        XCTAssertEqual(TrackerStripper().transform(input).absoluteString, "https://example.com/p?sig=ab%2Bcd%26e")
    }
}

final class PreviewLoadTrackerTests: XCTestCase {
    func test_redirected_page_is_not_reloaded() {
        var tracker = PreviewLoadTracker()
        let requested = URL(string: "http://example.com")!
        XCTAssertTrue(tracker.needsLoad(requested))
        // The web view now reports https://www.example.com/ after a redirect;
        // SwiftUI calls update again with the same requested URL.
        XCTAssertFalse(tracker.needsLoad(requested))
        XCTAssertFalse(tracker.needsLoad(requested))
    }

    func test_new_requested_url_loads() {
        var tracker = PreviewLoadTracker()
        XCTAssertTrue(tracker.needsLoad(URL(string: "https://a.example")!))
        XCTAssertTrue(tracker.needsLoad(URL(string: "https://b.example")!))
    }
}

final class PickerRememberHostTests: XCTestCase {
    func test_remember_host_is_the_unwrapped_target() {
        let url = URL(string: "https://eur06.safelinks.protection.outlook.com/?url=https%3A%2F%2Fwww.github.com%2Fa&data=x&reserved=0")!
        let model = PickerViewModel(
            url: url,
            options: [],
            context: RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil)),
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: {}
        )
        XCTAssertEqual(model.rememberHost, "github.com")
    }
}

final class BrowserDiscoveryExclusionTests: XCTestCase {
    func test_every_junction_variant_is_excluded() {
        XCTAssertTrue(BrowserDiscovery.isJunction(bundleID: "dev.gideonsarfo.Junction"))
        XCTAssertTrue(BrowserDiscovery.isJunction(bundleID: "dev.gideonsarfo.JunctionPreview"))
        XCTAssertFalse(BrowserDiscovery.isJunction(bundleID: "com.apple.Safari"))
    }
}

final class LaunchOptionCacheTests: XCTestCase {
    func test_serves_cached_list_and_refreshes_in_background_when_stale() {
        var scans = 0
        var now = Date(timeIntervalSince1970: 0)
        var queued: [() -> Void] = []
        let cache = LaunchOptionCache(
            maxAge: 5,
            now: { now },
            scan: { scans += 1; return [] },
            runInBackground: { queued.append($0) }
        )
        _ = cache.current()
        _ = cache.current()
        XCTAssertEqual(scans, 1)
        XCTAssertTrue(queued.isEmpty)

        now += 10
        _ = cache.current()
        XCTAssertEqual(scans, 1, "stale read must not block on a scan")
        XCTAssertEqual(queued.count, 1)
        _ = cache.current()
        XCTAssertEqual(queued.count, 1, "one refresh at a time")
        queued.removeFirst()()
        XCTAssertEqual(scans, 2)
    }
}

final class PreviewMediaTests: XCTestCase {
    func test_preview_does_not_autoplay_media() {
        let webView = PreviewWebViewFactory.makeWebView()
        XCTAssertEqual(webView.configuration.mediaTypesRequiringUserActionForPlayback, .all)
    }
}

final class FocusTrackerReadTests: XCTestCase {
    func test_focus_file_is_read_only_when_a_rule_needs_it() {
        var reads = 0
        let read: (URL) -> Data? = { _ in reads += 1; return nil }
        _ = FocusTracker.current(rules: [DomainRule(host: .equals("a.com"), action: .ask)], read: read)
        XCTAssertEqual(reads, 0)

        var focused = DomainRule(host: .equals("a.com"), action: .ask)
        focused.when = RuleCondition(focus: ["work"])
        _ = FocusTracker.current(rules: [focused], read: read)
        XCTAssertEqual(reads, 1)
    }
}
