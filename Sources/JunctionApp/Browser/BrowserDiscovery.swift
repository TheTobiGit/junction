import AppKit
import UniformTypeIdentifiers

enum BrowserDiscovery {
    private static let ownBundleID = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"

    static func installedBrowsers() -> [Browser] {
        let probe = URL(string: "https://example.com")!
        let ws = NSWorkspace.shared

        var urls = ws.urlsForApplications(toOpen: probe)

        for bid in knownBrowserBundleIDs {
            if let u = ws.urlForApplication(withBundleIdentifier: bid) {
                urls.append(u)
            }
        }

        var seen = Set<String>()
        var browsers: [Browser] = []

        for url in urls {
            guard let bundle = Bundle(url: url), let bid = bundle.bundleIdentifier else { continue }
            if bid == ownBundleID { continue }
            if isNestedHelperApp(url: url) { continue }
            if !seen.insert(bid).inserted { continue }

            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            browsers.append(Browser(bundleID: bid, name: name, url: url))
        }

        browsers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return browsers
    }

    private static func isNestedHelperApp(url: URL) -> Bool {
        let components = url.pathComponents
        var foundOuterApp = false
        for component in components {
            if component.hasSuffix(".app") {
                if foundOuterApp { return true }
                foundOuterApp = true
            }
        }
        return false
    }

    private static let knownBrowserBundleIDs: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "net.imput.helium",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "com.kagi.kagimacOS",
        "com.zen-browser.zen",
        "io.orionbrowser.Orion",
        "net.shinyfrog.Orion",
        "app.sigmaos.sigmaos",
    ]
}
