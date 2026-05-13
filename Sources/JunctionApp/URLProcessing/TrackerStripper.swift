import Foundation

struct TrackerStripper: URLTransformer {
    let identifier = "tracker-stripper"

    private static let exactParams: Set<String> = [
        "fbclid",
        "gclid",
        "gclsrc",
        "dclid",
        "yclid",
        "msclkid",
        "mc_eid",
        "mc_cid",
        "igshid",
        "ref",
        "ref_src",
        "ref_url",
        "_ga",
        "_gl",
        "vero_conv",
        "vero_id",
        "mkt_tok",
        "trk",
        "trkCampaign",
        "wickedid",
        "ranMID",
        "ranEAID",
        "ranSiteID",
        "s_cid",
        "icid",
        "_hsenc",
        "_hsmi",
        "__hstc",
        "__hssc",
        "__hsfp",
    ]

    private static let prefixes: [String] = [
        "utm_",
        "hsa_",
    ]

    func transform(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        guard let items = components.queryItems, !items.isEmpty else { return url }

        let cleaned = items.filter { item in
            !Self.shouldStrip(name: item.name)
        }

        if cleaned.count == items.count { return url }

        components.queryItems = cleaned.isEmpty ? nil : cleaned

        return components.url ?? url
    }

    private static func shouldStrip(name: String) -> Bool {
        let lower = name.lowercased()
        if exactParams.contains(lower) { return true }
        for prefix in prefixes where lower.hasPrefix(prefix) { return true }
        return false
    }
}
