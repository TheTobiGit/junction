import Foundation
import AppKit

struct LinkPreview {
    let title: String?
    let siteName: String?
    let faviconData: Data?
}

enum LinkPreviewFetcher {
    static func fetch(_ url: URL, timeout: TimeInterval = 2.5, completion: @escaping (LinkPreview?) -> Void) {
        Task { await fetch(url, timeout: timeout, cache: PreviewCache.shared, completion: completion) }
    }

    static func fetch(_ url: URL, cache: PreviewCache, timeout: TimeInterval = 2.5, completion: @escaping (LinkPreview?) -> Void) {
        Task { await fetch(url, timeout: timeout, cache: cache, completion: completion) }
    }

    private static func fetch(_ url: URL, timeout: TimeInterval, cache: PreviewCache, completion: @escaping (LinkPreview?) -> Void) async {
        if let payload = await cache.previewPayload(for: url) {
            let preview = LinkPreview(title: payload.title, siteName: payload.siteName, faviconData: payload.faviconData)
            await MainActor.run { completion(preview) }
            return
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpAdditionalHeaders = [
            "User-Agent": BrowserUserAgent.safariMacDesktop,
            "Accept": "text/html,application/xhtml+xml",
        ]
        let session = URLSession(configuration: config)

        let htmlResult = await loadHTML(session: session, url: url, timeout: timeout)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, responseURL, shouldPersistPreview) = htmlResult,
              let html = String(data: data.prefix(200_000), encoding: .utf8)
                ?? String(data: data.prefix(200_000), encoding: .isoLatin1)
        else {
            await MainActor.run { completion(nil) }
            return
        }

        let rawTitle = extractMetaContent(html: html, property: "og:title")
            ?? extractMetaContent(html: html, name: "twitter:title")
            ?? extractTitleTag(html: html)
        let rawSite = extractMetaContent(html: html, property: "og:site_name")

        let title = rawTitle.map { HTMLEntityDecoder.decode($0) }
        let siteName = rawSite.map { HTMLEntityDecoder.decode($0) }

        let baseURL = responseURL
        let faviconURL = discoverFaviconURL(html: html, baseURL: baseURL)

        let faviconData = await fetchFavicon(faviconURL, timeout: timeout)

        let preview = LinkPreview(title: title, siteName: siteName, faviconData: faviconData)
        if shouldPersistPreview {
            let payload = PreviewCache.CachedPreviewPayload(title: title, siteName: siteName, faviconData: faviconData)
            await cache.storePreview(payload, for: url)
        }
        await MainActor.run { completion(preview) }
    }

    /// - Returns: Body, final URL after redirects, and whether the response is safe to persist (HTTP(S) 2xx only).
    private static func loadHTML(session: URLSession, url: URL, timeout: TimeInterval) async -> (Data, URL, shouldPersistPreview: Bool)? {
        return await withCheckedContinuation { cont in
            let task = session.dataTask(with: url) { data, response, _ in
                guard let data else {
                    cont.resume(returning: nil)
                    return
                }
                let finalURL = response?.url ?? url
                let shouldPersist: Bool
                if let http = response as? HTTPURLResponse {
                    shouldPersist = (200...299).contains(http.statusCode)
                } else {
                    // Non-HTTP (or unexpected); still show a one-off preview but never poison disk/memory TTL caches.
                    shouldPersist = false
                }
                cont.resume(returning: (data, finalURL, shouldPersist))
            }
            task.resume()
        }
    }

    private static func fetchFavicon(_ url: URL?, timeout: TimeInterval) async -> Data? {
        guard let url else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: url) { data, response, _ in
                defer { session.finishTasksAndInvalidate() }
                if let data,
                   let http = response as? HTTPURLResponse,
                   (200...299).contains(http.statusCode),
                   data.count < 200_000,
                   NSImage(data: data) != nil {
                    cont.resume(returning: data)
                } else {
                    cont.resume(returning: nil)
                }
            }
            task.resume()
        }
    }

    private static func discoverFaviconURL(html: String, baseURL: URL) -> URL? {
        if let href = extractLinkHref(html: html, relContains: "apple-touch-icon")
            ?? extractLinkHref(html: html, relContains: "icon") {
            return URL(string: href, relativeTo: baseURL)?.absoluteURL
        }
        if var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            comps.path = "/favicon.ico"
            comps.query = nil
            comps.fragment = nil
            return comps.url
        }
        return nil
    }

    private static func extractMetaContent(html: String, property: String) -> String? {
        let pattern = "<meta[^>]+property\\s*=\\s*[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*content\\s*=\\s*[\"']([^\"']+)[\"']"
        return firstMatch(pattern: pattern, in: html, group: 1)
            ?? firstMatch(
                pattern: "<meta[^>]+content\\s*=\\s*[\"']([^\"']+)[\"'][^>]*property\\s*=\\s*[\"']\(NSRegularExpression.escapedPattern(for: property))[\"']",
                in: html, group: 1
            )
    }

    private static func extractMetaContent(html: String, name: String) -> String? {
        let pattern = "<meta[^>]+name\\s*=\\s*[\"']\(NSRegularExpression.escapedPattern(for: name))[\"'][^>]*content\\s*=\\s*[\"']([^\"']+)[\"']"
        return firstMatch(pattern: pattern, in: html, group: 1)
    }

    private static func extractTitleTag(html: String) -> String? {
        firstMatch(pattern: "<title[^>]*>([^<]+)</title>", in: html, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractLinkHref(html: String, relContains: String) -> String? {
        let pattern = "<link[^>]+rel\\s*=\\s*[\"']([^\"']*\(NSRegularExpression.escapedPattern(for: relContains))[^\"']*)[\"'][^>]*href\\s*=\\s*[\"']([^\"']+)[\"']"
        return firstMatch(pattern: pattern, in: html, group: 2)
    }

    private static func firstMatch(pattern: String, in html: String, group: Int) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = re.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > group
        else { return nil }
        let r = match.range(at: group)
        guard r.location != NSNotFound, let swiftRange = Range(r, in: html) else { return nil }
        return String(html[swiftRange])
    }
}
