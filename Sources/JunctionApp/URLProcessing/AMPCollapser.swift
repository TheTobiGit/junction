import Foundation

struct AMPCollapser: URLTransformer {
    let identifier = "amp-collapser"

    func transform(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        let host = comps.host?.lowercased() ?? ""

        // google.com/amp/s/<rest> — Google's AMP viewer.
        if host == "www.google.com" || host == "google.com",
           comps.path.hasPrefix("/amp/s/") {
            let stripped = String(comps.path.dropFirst("/amp/s/".count))
            if let recovered = URL(string: "https://" + stripped) {
                return recovered
            }
        }

        // <example-com>.cdn.ampproject.org/c/s/example.com/article — modern AMP CDN form.
        // The leading hostname is the publisher's domain with `.` replaced by `-`,
        // but we don't actually need it: the path /c/s/<host>/<rest> already encodes the canonical URL.
        if host.hasSuffix(".cdn.ampproject.org") || host == "cdn.ampproject.org" {
            for prefix in ["/c/s/", "/v/s/", "/c/", "/v/"] {
                guard comps.path.hasPrefix(prefix) else { continue }
                let payload = String(comps.path.dropFirst(prefix.count))
                let scheme = (prefix == "/c/s/" || prefix == "/v/s/") ? "https://" : "http://"
                var rebuilt = scheme + payload
                if let q = comps.percentEncodedQuery, !q.isEmpty { rebuilt += "?" + q }
                if let f = comps.percentEncodedFragment, !f.isEmpty { rebuilt += "#" + f }
                if let recovered = URL(string: rebuilt) {
                    return recovered
                }
            }
        }

        if comps.path.hasSuffix("/amp") {
            comps.path = String(comps.path.dropLast(4))
        } else if comps.path.hasSuffix("/amp/") {
            comps.path = String(comps.path.dropLast(5))
        } else if comps.path.hasSuffix(".amp") {
            comps.path = String(comps.path.dropLast(4))
        }

        if var items = comps.queryItems {
            items.removeAll { item in
                let lower = item.name.lowercased()
                if lower == "amp" { return true }
                if lower == "outputtype" && item.value == "amp" { return true }
                return false
            }
            comps.queryItems = items.isEmpty ? nil : items
        }

        return comps.url ?? url
    }
}
