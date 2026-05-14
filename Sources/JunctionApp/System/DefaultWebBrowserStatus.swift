import AppKit
import Foundation

enum DefaultWebBrowserStatus {
    /// `true` when this app’s bundle ID is the default handler for both `http` and `https`.
    static var isJunctionDefaultForHTTPAndHTTPS: Bool {
        let bid = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        guard
            let httpsApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
            let httpApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://example.com")!),
            let httpsBID = Bundle(url: httpsApp)?.bundleIdentifier,
            let httpBID = Bundle(url: httpApp)?.bundleIdentifier
        else {
            return false
        }
        return httpsBID == bid && httpBID == bid
    }
}
