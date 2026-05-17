import Foundation

struct TrackerStripper: URLTransformer {
    let identifier: String

    static let defaultExactParams: Set<String> = [
        // Big-ad-tech click IDs
        "fbclid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        "gclid", "gclsrc", "dclid", "yclid", "msclkid", "twclid",
        "ttclid", "li_fat_id", "wbraid", "gbraid", "epik", "rtid",
        "irclickid", "wickedid", "vero_conv", "vero_id", "oly_anon_id",

        // Email / CRM
        "mc_eid", "mc_cid", "mkt_tok", "_hsenc", "_hsmi",
        "__hstc", "__hssc", "__hsfp", "bsft_clkid", "bsft_uid",
        "vgo_ee", "_kx",

        // Social legacy
        "igshid", "igsh", "ref", "ref_src", "ref_url", "share",

        // Analytics misc
        "_ga", "_gl", "_branch_match_id", "_branch_referrer",
        "trk", "trkCampaign", "ranMID", "ranEAID", "ranSiteID",
        "s_cid", "icid", "cmpid", "ncid",

        // TikTok
        "_t", "_r", "share_app_id", "share_token", "share_link_id",
        "tt_from", "iid", "checksum",

        // YouTube
        "si", "feature", "kw", "ab_channel",

        // Reddit
        "rdt", "$deep_link", "$3p",

        // Misc tracker tokens
        "vero_token", "matomo_campaign", "matomo_kwd", "piwik_campaign", "piwik_kwd",
    ]

    static let defaultPrefixes: [String] = [
        "utm_",
        "hsa_",
        "oly_",
        "pk_",
        "matomo_",
        "piwik_",
        "at_",          // at_medium, at_campaign…
        "ga_",
    ]

    private let effectiveExactParams: Set<String>
    private let effectivePrefixes: [String]
    private let preservedByOverride: Set<String>

    init(overrides: TrackerOverrides = TrackerOverrides(), identifier: String = "tracker-stripper") {
        self.identifier = identifier
        var exact = Self.defaultExactParams
        var prefixes = Self.defaultPrefixes
        var preserved: Set<String> = []

        for entry in overrides.disabled {
            let lower = entry.lowercased()
            if lower.hasSuffix("_") {
                prefixes.removeAll { $0 == lower }
            } else {
                exact.remove(lower)
                preserved.insert(lower)
            }
        }

        for entry in overrides.additions {
            let lower = entry.lowercased()
            if lower.hasSuffix("_") {
                if !prefixes.contains(lower) { prefixes.append(lower) }
            } else {
                exact.insert(lower)
            }
        }

        self.effectiveExactParams = exact
        self.effectivePrefixes = prefixes
        self.preservedByOverride = preserved
    }

    /// Hosts where the listed parameters are actually load-bearing and should not be stripped.
    /// Per-host overrides win over the global rules above.
    private static let hostKeepList: [String: Set<String>] = [
        "amazon.com": ["ref"],
        "amazon.co.uk": ["ref"],
        "amazon.de": ["ref"],
        "amazon.fr": ["ref"],
        "amazon.ca": ["ref"],
        "amazon.in": ["ref"],
    ]

    /// Per-host extra strip list. These params are stripped *only* when the
    /// URL's host matches the suffix; they're too short / generic to live on
    /// the global list (e.g. `s` is WordPress's search query elsewhere). Used
    /// for site-specific share tokens.
    private static let hostStripList: [String: Set<String>] = [
        "twitter.com": ["s", "t"],
        "x.com":       ["s", "t"],
    ]

    func transform(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        guard let items = components.queryItems, !items.isEmpty else { return url }

        let host = url.host?.lowercased() ?? ""
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let preserved = Self.preservedFor(host: bare)
        let extraStrip = Self.extraStripFor(host: bare)

        let cleaned = items.filter { item in
            let lower = item.name.lowercased()
            if preserved.contains(lower) { return true }
            if extraStrip.contains(lower) { return false }
            return !shouldStrip(name: item.name)
        }

        if cleaned.count == items.count { return url }

        components.queryItems = cleaned.isEmpty ? nil : cleaned

        return components.url ?? url
    }

    private static func preservedFor(host: String) -> Set<String> {
        var out: Set<String> = []
        for (suffix, keep) in hostKeepList where host == suffix || host.hasSuffix("." + suffix) {
            out.formUnion(keep)
        }
        return out
    }

    private static func extraStripFor(host: String) -> Set<String> {
        var out: Set<String> = []
        for (suffix, strip) in hostStripList where host == suffix || host.hasSuffix("." + suffix) {
            out.formUnion(strip)
        }
        return out
    }

    private func shouldStrip(name: String) -> Bool {
        let lower = name.lowercased()
        if preservedByOverride.contains(lower) { return false }
        if effectiveExactParams.contains(lower) { return true }
        for prefix in effectivePrefixes where lower.hasPrefix(prefix) { return true }
        return false
    }
}
