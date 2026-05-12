import Foundation

struct DomainRedirect: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var fromHost: String
    var toHost: String
    var enabled: Bool = true
    var label: String? = nil

    func apply(to url: URL) -> URL? {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let host = comps.host?.lowercased() else { return nil }
        let needle = fromHost.lowercased()
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        guard bare == needle || bare.hasSuffix("." + needle) else { return nil }
        comps.host = toHost
        return comps.url
    }
}

struct RedirectTransformer: URLTransformer {
    let identifier = "domain-redirect"
    let redirects: [DomainRedirect]

    func transform(_ url: URL) -> URL {
        for redirect in redirects where redirect.enabled {
            if let rewritten = redirect.apply(to: url) { return rewritten }
        }
        return url
    }
}

enum DefaultRedirects {
    static let all: [DomainRedirect] = [
        DomainRedirect(fromHost: "twitter.com", toHost: "nitter.net", enabled: false, label: "Twitter → Nitter"),
        DomainRedirect(fromHost: "x.com", toHost: "nitter.net", enabled: false, label: "X → Nitter"),
        DomainRedirect(fromHost: "reddit.com", toHost: "old.reddit.com", enabled: false, label: "Reddit → old.reddit"),
        DomainRedirect(fromHost: "medium.com", toHost: "freedium.cfd", enabled: false, label: "Medium → freedium"),
    ]
}
