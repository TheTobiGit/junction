import XCTest
@testable import JunctionApp

final class HostFaviconFetcherTests: XCTestCase {
    func test_remoteIconHostAllowsPublicDomainNames() {
        XCTAssertEqual(HostFaviconFetcher.remoteIconHost(for: " Example.COM "), "example.com")
        XCTAssertEqual(HostFaviconFetcher.remoteIconHost(for: "subdomain.example.co.uk."), "subdomain.example.co.uk")
        XCTAssertEqual(HostFaviconFetcher.remoteIconHost(for: "xn--e1afmkfd.xn--p1ai"), "xn--e1afmkfd.xn--p1ai")
    }

    func test_remoteIconHostRejectsPrivateOrLocalNames() {
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "localhost"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "printer"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "router.local"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "dashboard.internal"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "service.corp"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "nas.lan"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "sample.test"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "docs.example"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "host.home.arpa"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "hidden.onion"))
    }

    func test_remoteIconHostRejectsIpLiterals() {
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "127.0.0.1"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "192.168.1.44"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "10.0.0.12"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "8.8.8.8"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "[fd00::1]"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "2001:4860:4860::8888"))
    }

    func test_remoteIconHostRejectsInvalidHostText() {
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "example.com/path"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "bad host.example"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "-example.com"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "example-.com"))
        XCTAssertNil(HostFaviconFetcher.remoteIconHost(for: "example.123"))
    }
}
