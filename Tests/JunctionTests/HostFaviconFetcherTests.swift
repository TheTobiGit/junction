import AppKit
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

    func test_faviconFetcherUsesMemoryCache() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = PreviewCache(rootDirectory: tmp)
        let png = Self.samplePNGData()
        await cache.storeFavicon(png, for: "example.com")

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            HostFaviconFetcher.fetch(host: "example.com", cache: cache) { data in
                XCTAssertEqual(data, png)
                cont.resume()
            }
        }
    }

    func test_faviconFetcherUsesDiskCacheAcrossInstances() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache1 = PreviewCache(rootDirectory: tmp)
        let png = Self.samplePNGData()
        await cache1.storeFavicon(png, for: "example.com")

        let cache2 = PreviewCache(rootDirectory: tmp)
        let fetched = await cache2.favicon(for: "example.com")
        XCTAssertEqual(fetched, png)
    }

    private static func samplePNGData() -> Data {
        let img = NSImage(size: NSSize(width: 16, height: 16))
        img.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            fatalError("fixture PNG")
        }
        return png
    }
}
