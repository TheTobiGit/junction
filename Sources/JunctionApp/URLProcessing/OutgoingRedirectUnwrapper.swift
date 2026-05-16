import Foundation

/// Unwraps "tracking link" URLs whose real destination is sitting in a query parameter,
/// e.g. `l.facebook.com/l.php?u=…`, `google.com/url?q=…`, `youtube.com/redirect?q=…`.
///
/// Unlike ``ShortenerExpander`` this performs no network I/O: the destination is already
/// embedded as a percent-encoded value, so we just decode and substitute it.
struct OutgoingRedirectUnwrapper: URLTransformer {
    let identifier = "outgoing-redirect-unwrapper"
    /// Hard cap so a wrapper-of-wrapper-of-wrapper can't loop indefinitely.
    private static let maxHops = 4

    /// Host suffix → ordered list of query parameter names that hold the embedded URL.
    /// First match wins per hop. Suffix match means `*.facebook.com` etc.
    private static let rules: [(hostSuffix: String, params: [String], pathPrefix: String?)] = [
        ("l.facebook.com",        ["u"],                  nil),
        ("lm.facebook.com",       ["u"],                  nil),
        ("l.instagram.com",       ["u"],                  nil),
        ("l.messenger.com",       ["u"],                  nil),
        ("l.linkedin.com",        ["url"],                nil),
        ("linkedin.com",          ["url"],                "/redir"),
        ("out.reddit.com",        ["url"],                nil),
        ("away.vk.com",           ["to"],                 nil),
        ("l.threads.net",         ["u"],                  nil),
        ("l.threads.com",         ["u"],                  nil),

        ("youtube.com",           ["q"],                  "/redirect"),
        ("www.youtube.com",       ["q"],                  "/redirect"),
        ("google.com",            ["q", "url"],           "/url"),
        ("www.google.com",        ["q", "url"],           "/url"),
        ("googleadservices.com",  ["adurl", "url"],       nil),
        ("duckduckgo.com",        ["uddg", "u"],          "/l/"),
        ("bing.com",              ["u"],                  "/ck/a"),

        ("t.umblr.com",           ["z"],                  "/redirect"),
        ("disq.us",               ["url"],                "/url"),
        ("steamcommunity.com",    ["url"],                "/linkfilter/"),

        ("href.li",               ["u"],                  nil),
        ("anonym.to",             [],                     nil),
    ]

    func transform(_ url: URL) -> URL {
        var current = url
        for _ in 0..<Self.maxHops {
            guard let unwrapped = Self.unwrapOnce(current), unwrapped != current else { return current }
            current = unwrapped
        }
        return current
    }

    static func unwrapOnce(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let path = url.path

        // Special path-only unwraps (e.g. anonym.to/?https://…).
        if bare == "anonym.to" {
            if let q = url.query?.removingPercentEncoding,
               let recovered = URL(string: q),
               let scheme = recovered.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return recovered
            }
            return nil
        }

        for rule in rules {
            guard hostMatches(bare: bare, suffix: rule.hostSuffix) else { continue }
            if let prefix = rule.pathPrefix, !path.hasPrefix(prefix) { continue }

            guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let items = comps.queryItems, !items.isEmpty
            else { continue }

            for name in rule.params {
                guard let raw = items.first(where: { $0.name.lowercased() == name.lowercased() })?.value,
                      !raw.isEmpty
                else { continue }
                if let recovered = recover(raw),
                   let scheme = recovered.scheme?.lowercased(),
                   scheme == "http" || scheme == "https",
                   recovered.host != nil {
                    return recovered
                }
            }
        }
        return nil
    }

    private static func hostMatches(bare: String, suffix: String) -> Bool {
        let needle = suffix.lowercased()
        return bare == needle || bare.hasSuffix("." + needle)
    }

    /// Some wrappers double-encode (`https%3A%2F%2F`), some don't.
    /// `URL(string:)` is happy with both forms once we run `removingPercentEncoding`.
    private static func recover(_ raw: String) -> URL? {
        if let direct = URL(string: raw), direct.scheme != nil { return direct }
        if let decoded = raw.removingPercentEncoding, let url = URL(string: decoded) { return url }
        return nil
    }
}
