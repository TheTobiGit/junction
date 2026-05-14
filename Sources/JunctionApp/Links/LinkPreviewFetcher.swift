import Foundation
import AppKit

struct LinkPreview {
    let title: String?
    let siteName: String?
    let faviconData: Data?
}

enum LinkPreviewFetcher {
    static func fetch(_ url: URL, timeout: TimeInterval = 2.5, completion: @escaping (LinkPreview?) -> Void) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpAdditionalHeaders = [
            "User-Agent": BrowserUserAgent.safariMacDesktop,
            "Accept": "text/html,application/xhtml+xml",
        ]
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: url) { data, response, _ in
            defer { session.finishTasksAndInvalidate() }
            guard let data, let html = String(data: data.prefix(200_000), encoding: .utf8)
                ?? String(data: data.prefix(200_000), encoding: .isoLatin1)
            else {
                completion(nil)
                return
            }
            let title = extractMetaContent(html: html, property: "og:title")
                ?? extractMetaContent(html: html, name: "twitter:title")
                ?? extractTitleTag(html: html)
            let siteName = extractMetaContent(html: html, property: "og:site_name")

            let baseURL = (response?.url ?? url)
            let faviconURL = discoverFaviconURL(html: html, baseURL: baseURL)

            fetchFavicon(faviconURL, timeout: timeout) { faviconData in
                let preview = LinkPreview(
                    title: title,
                    siteName: siteName,
                    faviconData: faviconData
                )
                completion(preview)
            }
        }
        task.resume()
    }

    private static func fetchFavicon(_ url: URL?, timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        guard let url else {
            completion(nil)
            return
        }
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
                completion(data)
            } else {
                completion(nil)
            }
        }
        task.resume()
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
