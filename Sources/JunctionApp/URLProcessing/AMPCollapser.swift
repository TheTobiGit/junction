import Foundation

struct AMPCollapser: URLTransformer {
    let identifier = "amp-collapser"

    func transform(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        let host = comps.host?.lowercased() ?? ""

        if host == "www.google.com" || host == "google.com",
           comps.path.hasPrefix("/amp/s/") {
            let stripped = String(comps.path.dropFirst("/amp/s/".count))
            if let recovered = URL(string: "https://" + stripped) {
                return recovered
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
            items.removeAll { $0.name.lowercased() == "amp" || $0.name.lowercased() == "outputtype" && $0.value == "amp" }
            comps.queryItems = items.isEmpty ? nil : items
        }

        return comps.url ?? url
    }
}
