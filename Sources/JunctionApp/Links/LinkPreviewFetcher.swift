import Foundation
import AppKit

struct LinkPreview {
    let title: String?
    let siteName: String?
    let description: String?
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
            let preview = LinkPreview(
                title: payload.title,
                siteName: payload.siteName,
                description: payload.description,
                faviconData: payload.faviconData
            )
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

        guard let (data, responseURL, contentType, shouldPersistPreview) = htmlResult else {
            await MainActor.run { completion(nil) }
            return
        }
        // Bail out for non-HTML payloads (PDF, image/*, video/*, …) — running
        // regex over a binary blob is wasteful and produces garbage titles.
        guard isHTMLLikeContentType(contentType) else {
            await MainActor.run { completion(nil) }
            return
        }
        let prefix = data.prefix(200_000)
        guard let html = decodeHTML(prefix, contentType: contentType) else {
            await MainActor.run { completion(nil) }
            return
        }

        let rawTitle = extractMetaContent(html: html, property: "og:title")
            ?? extractMetaContent(html: html, name: "twitter:title")
            ?? extractTitleTag(html: html)
        let rawSite = extractMetaContent(html: html, property: "og:site_name")
        let rawDescription = extractMetaContent(html: html, property: "og:description")
            ?? extractMetaContent(html: html, name: "twitter:description")
            ?? extractMetaContent(html: html, name: "description")

        let title = rawTitle.map { HTMLEntityDecoder.decode($0) }
        let siteName = rawSite.map { HTMLEntityDecoder.decode($0) }
        let description = rawDescription
            .map { HTMLEntityDecoder.decode($0) }
            .map { trimmedDescription($0) }

        let baseURL = responseURL
        let faviconURL = discoverFaviconURL(html: html, baseURL: baseURL)

        let faviconData = await fetchFavicon(faviconURL, timeout: timeout)

        let preview = LinkPreview(
            title: title,
            siteName: siteName,
            description: description,
            faviconData: faviconData
        )
        if shouldPersistPreview {
            let payload = PreviewCache.CachedPreviewPayload(
                title: title,
                siteName: siteName,
                description: description,
                faviconData: faviconData
            )
            await cache.storePreview(payload, for: url)
        }
        await MainActor.run { completion(preview) }
    }

    private static func trimmedDescription(_ s: String) -> String {
        let collapsed = s
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 280 else { return collapsed }
        let cutoff = collapsed.index(collapsed.startIndex, offsetBy: 280)
        return collapsed[..<cutoff].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// - Returns: Body, final URL, response Content-Type, and whether the response is safe to persist.
    /// `shouldPersistPreview` is false for non-2xx responses, non-HTTP responses, and any response
    /// whose `Cache-Control` indicates the payload should not be stored (`no-store` / `private`).
    private static func loadHTML(session: URLSession, url: URL, timeout: TimeInterval) async -> (Data, URL, String?, shouldPersistPreview: Bool)? {
        return await withCheckedContinuation { cont in
            let task = session.dataTask(with: url) { data, response, _ in
                guard let data else {
                    cont.resume(returning: nil)
                    return
                }
                let finalURL = response?.url ?? url
                let http = response as? HTTPURLResponse
                let contentType = http?.value(forHTTPHeaderField: "Content-Type")
                let cacheControl = http?.value(forHTTPHeaderField: "Cache-Control")
                let shouldPersist: Bool
                if let http {
                    shouldPersist = (200...299).contains(http.statusCode)
                        && allowsPersistedPreview(cacheControl: cacheControl)
                } else {
                    shouldPersist = false
                }
                cont.resume(returning: (data, finalURL, contentType, shouldPersist))
            }
            task.resume()
        }
    }

    /// `Cache-Control: no-store` and `private` (with no other directive overriding it)
    /// are signals that the response shouldn't be persisted to a long-lived cache.
    static func allowsPersistedPreview(cacheControl: String?) -> Bool {
        guard let cacheControl else { return true }
        let directives = cacheControl
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if directives.contains("no-store") { return false }
        if directives.contains("private") { return false }
        return true
    }

    static func isHTMLLikeContentType(_ contentType: String?) -> Bool {
        guard let contentType else { return true }   // missing header → tolerate, parse leniently
        let lower = contentType.lowercased()
        if lower.hasPrefix("text/html") { return true }
        if lower.hasPrefix("application/xhtml") { return true }
        if lower.hasPrefix("application/xml") { return true }
        if lower.hasPrefix("text/xml") { return true }
        if lower.hasPrefix("text/plain") { return true }   // some servers misreport; titles still parseable
        return false
    }

    /// Picks a string encoding from the response Content-Type charset, then
    /// from a `<meta charset>` declaration in the prefix, falling back to
    /// UTF-8 then ISO-Latin-1.
    static func decodeHTML(_ data: Data.SubSequence, contentType: String?) -> String? {
        if let charset = charsetFromContentType(contentType),
           let encoding = stringEncoding(forIANAName: charset),
           let s = String(data: Data(data), encoding: encoding) {
            return s
        }
        if let metaCharset = extractMetaCharset(data: data),
           let encoding = stringEncoding(forIANAName: metaCharset),
           let s = String(data: Data(data), encoding: encoding) {
            return s
        }
        if let utf8 = String(data: Data(data), encoding: .utf8) { return utf8 }
        return String(data: Data(data), encoding: .isoLatin1)
    }

    private static func charsetFromContentType(_ contentType: String?) -> String? {
        guard let contentType else { return nil }
        for piece in contentType.split(separator: ";") {
            let kv = piece.trimmingCharacters(in: .whitespaces)
            if kv.lowercased().hasPrefix("charset=") {
                let value = kv.dropFirst("charset=".count)
                return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            }
        }
        return nil
    }

    /// Looks at the first ~4KB of bytes for `<meta charset="…">` or
    /// `<meta http-equiv=Content-Type content="…charset=…">`.
    private static func extractMetaCharset(data: Data.SubSequence) -> String? {
        let head = String(data: Data(data.prefix(4_000)), encoding: .ascii) ?? ""
        let patterns = [
            "<meta[^>]+charset\\s*=\\s*[\"']?([A-Za-z0-9_\\-:.]+)",
            "<meta[^>]+content\\s*=\\s*[\"'][^\"']*charset\\s*=\\s*([A-Za-z0-9_\\-:.]+)",
        ]
        for p in patterns {
            if let m = firstMatch(pattern: p, in: head, group: 1) { return m }
        }
        return nil
    }

    private static func stringEncoding(forIANAName name: String) -> String.Encoding? {
        let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cf != kCFStringEncodingInvalidId else { return nil }
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: nsEnc)
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
        metaContent(html: html, attribute: "property", value: property)
    }

    private static func extractMetaContent(html: String, name: String) -> String? {
        metaContent(html: html, attribute: "name", value: name)
    }

    /// Looks at every `<meta …>` tag, parses its attributes regardless of
    /// quoting style or ordering, and returns the `content` value of the tag
    /// whose `<attribute>` equals `<value>`.
    static func metaContent(html: String, attribute: String, value: String) -> String? {
        let needle = value.lowercased()
        let lowerAttr = attribute.lowercased()
        for tag in metaTags(in: html) {
            let attrs = parseTagAttributes(tag)
            guard attrs[lowerAttr]?.lowercased() == needle else { continue }
            if let content = attrs["content"], !content.isEmpty {
                return content
            }
        }
        return nil
    }

    private static func metaTags(in html: String) -> [String] {
        // Permissive: any `<meta` opener up to the next `>` (including across newlines).
        guard let re = try? NSRegularExpression(
            pattern: "<meta\\b[^>]*>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        return re.matches(in: html, range: range).compactMap { match -> String? in
            let r = match.range(at: 0)
            guard r.location != NSNotFound else { return nil }
            return nsString.substring(with: r)
        }
    }

    /// Tiny attribute parser that handles `key="value"`, `key='value'`, and
    /// unquoted `key=value`, ignoring trailing `/`. Values are HTML-entity-decoded.
    static func parseTagAttributes(_ tag: String) -> [String: String] {
        var out: [String: String] = [:]
        // Strip leading "<tagname" and trailing "/?>".
        var i = tag.startIndex
        if i < tag.endIndex, tag[i] == "<" { i = tag.index(after: i) }
        // Skip the tag name (letters/digits/-).
        while i < tag.endIndex, tag[i].isLetter || tag[i].isNumber || tag[i] == "-" {
            i = tag.index(after: i)
        }

        while i < tag.endIndex {
            // skip whitespace
            while i < tag.endIndex, tag[i].isWhitespace { i = tag.index(after: i) }
            if i >= tag.endIndex { break }
            if tag[i] == ">" || tag[i] == "/" { break }

            // attribute name
            let nameStart = i
            while i < tag.endIndex,
                  tag[i] != "=", tag[i] != ">", tag[i] != "/",
                  !tag[i].isWhitespace {
                i = tag.index(after: i)
            }
            let nameEnd = i
            let name = String(tag[nameStart..<nameEnd]).lowercased()
            guard !name.isEmpty else { break }

            // skip whitespace before =
            while i < tag.endIndex, tag[i].isWhitespace { i = tag.index(after: i) }
            guard i < tag.endIndex, tag[i] == "=" else {
                // valueless attribute
                out[name] = ""
                continue
            }
            i = tag.index(after: i)
            while i < tag.endIndex, tag[i].isWhitespace { i = tag.index(after: i) }
            if i >= tag.endIndex { out[name] = ""; break }

            let value: String
            if tag[i] == "\"" || tag[i] == "'" {
                let quote = tag[i]
                i = tag.index(after: i)
                let valueStart = i
                while i < tag.endIndex, tag[i] != quote { i = tag.index(after: i) }
                value = String(tag[valueStart..<i])
                if i < tag.endIndex { i = tag.index(after: i) }
            } else {
                // Per HTML, unquoted attribute values terminate on whitespace
                // or `>`. Slashes are valid inside the value (e.g.
                // `href=/favicon.ico` or `href=https://example.com`), so don't
                // stop on `/`. Strip a single trailing slash that turns out to
                // be the self-closing marker right before `>`.
                let valueStart = i
                while i < tag.endIndex, !tag[i].isWhitespace, tag[i] != ">" {
                    i = tag.index(after: i)
                }
                var raw = String(tag[valueStart..<i])
                if raw.hasSuffix("/"),
                   i < tag.endIndex, tag[i] == ">" {
                    raw.removeLast()
                }
                value = raw
            }
            out[name] = HTMLEntityDecoder.decode(value)
        }
        return out
    }

    private static func extractTitleTag(html: String) -> String? {
        firstMatch(pattern: "<title[^>]*>([^<]+)</title>", in: html, group: 1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractLinkHref(html: String, relContains: String) -> String? {
        guard let re = try? NSRegularExpression(
            pattern: "<link\\b[^>]*>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        for match in re.matches(in: html, range: range) {
            let tag = nsString.substring(with: match.range(at: 0))
            let attrs = parseTagAttributes(tag)
            guard let rel = attrs["rel"]?.lowercased(),
                  rel.contains(relContains.lowercased()),
                  let href = attrs["href"], !href.isEmpty
            else { continue }
            return href
        }
        return nil
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
