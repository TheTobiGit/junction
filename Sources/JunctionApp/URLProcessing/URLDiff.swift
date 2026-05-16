import Foundation

/// Helpers for explaining differences between two URLs in user-facing terms.
enum URLDiff {
    /// Returns the names of query parameters present in `original` but missing
    /// from `final`, in their original order. Used by the URL inspector to
    /// surface "we removed: utm_source, fbclid, …".
    static func strippedQueryParams(from original: URL, to final: URL) -> [String] {
        let originalItems = queryItems(for: original)
        guard !originalItems.isEmpty else { return [] }
        let finalNames: Set<String> = Set(queryItems(for: final).map { $0.name })

        var seen = Set<String>()
        var stripped: [String] = []
        for item in originalItems where !finalNames.contains(item.name) {
            if seen.insert(item.name).inserted {
                stripped.append(item.name)
            }
        }
        return stripped
    }

    /// Returns the params actually removed by the `tracker-stripper` stage of
    /// `trace`, if any. Diffing across the whole pipeline is misleading when
    /// an earlier stage rewrote the host (e.g. unwrapping `l.facebook.com`
    /// surfaces the wrapper's `u`/`h` as "removed", even though `u` *was* the
    /// real destination). Pinning the diff to the tracker-stripper step keeps
    /// the chip honest.
    static func strippedTrackerParams(in trace: URLTransformResult) -> [String] {
        guard let step = trace.steps.first(where: { $0.identifier == "tracker-stripper" }) else {
            return []
        }
        return strippedQueryParams(from: step.before, to: step.after)
    }

    private static func queryItems(for url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
