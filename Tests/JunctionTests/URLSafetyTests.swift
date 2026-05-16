import XCTest
@testable import JunctionApp

final class URLSafetyTests: XCTestCase {
    func test_publicHosts_are_routable() {
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("example.com"))
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("sub.example.co.uk"))
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("github.com"))
    }

    func test_loopback_and_private_ipv4_rejected() {
        for host in [
            "127.0.0.1",
            "10.0.0.5",
            "10.255.255.255",
            "172.16.0.1",
            "172.31.255.254",
            "192.168.1.1",
            "169.254.169.254",  // AWS IMDS
            "0.0.0.0",
        ] {
            XCTAssertFalse(URLSafety.isPubliclyRoutableHost(host), "expected \(host) to be private")
        }
    }

    func test_test_net_and_multicast_rejected() {
        for host in ["192.0.2.1", "198.51.100.5", "203.0.113.7", "224.0.0.1", "240.0.0.1"] {
            XCTAssertFalse(URLSafety.isPubliclyRoutableHost(host), "expected \(host) to be private")
        }
    }

    func test_public_ipv4_accepted() {
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("8.8.8.8"))
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("1.1.1.1"))
    }

    func test_ipv6_loopback_and_local_rejected() {
        for host in ["::1", "::", "fe80::1", "fc00::1", "fd00::1", "ff02::1"] {
            XCTAssertFalse(URLSafety.isPubliclyRoutableHost(host), "expected \(host) to be private")
        }
    }

    func test_ipv6_public_accepted() {
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("2606:4700:4700::1111"))
    }

    func test_ipv4_mapped_ipv6_inherits_v4_classification() {
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("::ffff:127.0.0.1"))
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("::ffff:8.8.8.8"))
    }

    func test_blocked_suffixes_rejected() {
        for host in [
            "router.local",
            "service.internal",
            "thing.lan",
            "anything.test",
            "site.invalid",
            "xyz.onion",
            "localhost",
            "bare",  // no dot
        ] {
            XCTAssertFalse(URLSafety.isPubliclyRoutableHost(host), "expected \(host) to be private")
        }
    }

    func test_isRoutableWebURL_filters_non_http() {
        XCTAssertTrue(URLSafety.isRoutableWebURL(URL(string: "https://example.com")!))
        XCTAssertTrue(URLSafety.isRoutableWebURL(URL(string: "http://example.com")!))
        XCTAssertFalse(URLSafety.isRoutableWebURL(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(URLSafety.isRoutableWebURL(URL(string: "file:///etc/passwd")!))
        XCTAssertFalse(URLSafety.isRoutableWebURL(URL(string: "data:text/html,evil")!))
    }
}
