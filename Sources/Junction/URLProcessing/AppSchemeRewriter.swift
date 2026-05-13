import AppKit

struct AppSchemeRewrite: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bundleID: String
    var enabled: Bool
    var rules: [AppSchemeRule]
}

struct AppSchemeRule: Codable, Hashable {
    enum Kind: String, Codable { case hostEquals, hostSuffix }
    var kind: Kind
    var host: String
    var pathPattern: String?
    var schemeTemplate: String

    func rewrite(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let needle = self.host.lowercased()
        switch kind {
        case .hostEquals:
            if bare != needle { return nil }
        case .hostSuffix:
            if bare != needle && !bare.hasSuffix("." + needle) { return nil }
        }

        let path = url.path.isEmpty ? "/" : url.path

        var pathMatches: [String] = []
        if let pattern = pathPattern {
            guard let captures = AppSchemeRule.match(pattern: pattern, in: path) else { return nil }
            pathMatches = captures
        }

        var output = schemeTemplate
        let query = url.query ?? ""
        let fragment = url.fragment ?? ""
        let hostValue = url.host ?? ""
        let absolute = url.absoluteString

        output = output.replacingOccurrences(of: "{host}", with: hostValue)
        output = output.replacingOccurrences(of: "{path}", with: path)
        output = output.replacingOccurrences(of: "{pathNoSlash}", with: String(path.drop(while: { $0 == "/" })))
        output = output.replacingOccurrences(of: "{query}", with: query)
        output = output.replacingOccurrences(of: "{fragment}", with: fragment)
        output = output.replacingOccurrences(of: "{url}", with: absolute)

        for (i, capture) in pathMatches.enumerated() {
            output = output.replacingOccurrences(of: "{$\(i + 1)}", with: capture)
        }

        return URL(string: output)
    }

    private static func match(pattern: String, in text: String) -> [String]? {
        var regex = "^"
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let ch = pattern[i]
            if ch == "*" {
                regex += "(.*)"
            } else if ch == "?" {
                regex += "(.)"
            } else if ".+()[]{}|^$\\".contains(ch) {
                regex += "\\\(ch)"
            } else {
                regex.append(ch)
            }
            i = pattern.index(after: i)
        }
        regex += "$"
        guard let re = try? NSRegularExpression(pattern: regex) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, range: range) else { return nil }
        var captures: [String] = []
        for group in 1..<match.numberOfRanges {
            let r = match.range(at: group)
            if let swiftRange = Range(r, in: text) {
                captures.append(String(text[swiftRange]))
            } else {
                captures.append("")
            }
        }
        return captures
    }
}

enum AppSchemeCatalog {
    static let defaults: [AppSchemeRewrite] = [
        AppSchemeRewrite(
            id: "slack",
            name: "Slack",
            bundleID: "com.tinyspeck.slackmacgap",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "slack.com",
                    pathPattern: "/archives/*",
                    schemeTemplate: "slack://open"
                ),
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "slack.com",
                    pathPattern: nil,
                    schemeTemplate: "slack://open"
                ),
            ]
        ),
        AppSchemeRewrite(
            id: "linear",
            name: "Linear",
            bundleID: "com.linear",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostEquals,
                    host: "linear.app",
                    pathPattern: nil,
                    schemeTemplate: "linear://{path}{query}"
                ),
            ]
        ),
        AppSchemeRewrite(
            id: "figma",
            name: "Figma",
            bundleID: "com.figma.Desktop",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "figma.com",
                    pathPattern: "/file/*",
                    schemeTemplate: "figma://{path}{query}"
                ),
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "figma.com",
                    pathPattern: "/design/*",
                    schemeTemplate: "figma://{path}{query}"
                ),
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "figma.com",
                    pathPattern: "/proto/*",
                    schemeTemplate: "figma://{path}{query}"
                ),
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "figma.com",
                    pathPattern: "/board/*",
                    schemeTemplate: "figma://{path}{query}"
                ),
            ]
        ),
        AppSchemeRewrite(
            id: "notion",
            name: "Notion",
            bundleID: "notion.id",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "notion.so",
                    pathPattern: nil,
                    schemeTemplate: "notion://{host}{path}{query}"
                ),
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "notion.site",
                    pathPattern: nil,
                    schemeTemplate: "notion://{host}{path}{query}"
                ),
            ]
        ),
        AppSchemeRewrite(
            id: "zoom",
            name: "Zoom",
            bundleID: "us.zoom.xos",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "zoom.us",
                    pathPattern: "/j/*",
                    schemeTemplate: "zoommtg://zoom.us/join?confno={$1}"
                ),
            ]
        ),
        AppSchemeRewrite(
            id: "tower",
            name: "Tower",
            bundleID: "com.fournova.Tower3",
            enabled: false,
            rules: [
                AppSchemeRule(
                    kind: .hostSuffix,
                    host: "github.com",
                    pathPattern: "/*/*",
                    schemeTemplate: "gittower://openRepo/https://github.com{path}"
                ),
            ]
        ),
    ]
}

enum AppSchemeRewriter {
    static func rewrite(_ url: URL, using rewrites: [AppSchemeRewrite]) -> URL? {
        for rewrite in rewrites where rewrite.enabled {
            guard Self.isAppInstalled(bundleID: rewrite.bundleID) else { continue }
            for rule in rewrite.rules {
                if let rewritten = rule.rewrite(url) { return rewritten }
            }
        }
        return nil
    }

    private static var installedCache: [String: Bool] = [:]
    private static let cacheQueue = DispatchQueue(label: "junction.appscheme.cache")

    private static func isAppInstalled(bundleID: String) -> Bool {
        cacheQueue.sync {
            if let cached = installedCache[bundleID] { return cached }
            let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
            installedCache[bundleID] = installed
            return installed
        }
    }

    static func refreshCache() {
        cacheQueue.sync { installedCache.removeAll() }
    }
}
