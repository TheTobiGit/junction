import AppKit
import Foundation

struct DefaultWebBrowserStatus {
    var isJunctionDefaultForHTTPAndHTTPS: Bool

    static var current: DefaultWebBrowserStatus {
        let bid = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        guard
            let httpsApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
            let httpApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://example.com")!),
            let httpsBID = Bundle(url: httpsApp)?.bundleIdentifier,
            let httpBID = Bundle(url: httpApp)?.bundleIdentifier
        else {
            return DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: false)
        }
        return DefaultWebBrowserStatus(isJunctionDefaultForHTTPAndHTTPS: httpsBID == bid && httpBID == bid)
    }
}
