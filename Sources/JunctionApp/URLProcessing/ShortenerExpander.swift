import Foundation

enum ShortenerExpander {
    static let knownShortenerHosts: Set<String> = [
        "t.co", "bit.ly", "lnkd.in", "buff.ly", "goo.gl", "ow.ly",
        "tinyurl.com", "is.gd", "youtu.be", "wp.me", "amzn.to", "dlvr.it",
        "tr.im", "cutt.ly", "shorturl.at", "rebrand.ly", "short.io",
        "s.id", "t.ly", "go.gle", "bit.do", "soo.gd", "qr.ae",
        "v.gd", "x.gd", "trib.al", "fb.me", "fal.cn", "lnk.to",
        "spoti.fi", "apple.co", "ift.tt",
    ]

    static func isShortened(_ url: URL) -> Bool {
        guard var host = url.host?.lowercased() else { return false }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return knownShortenerHosts.contains(host)
    }

    static func expand(_ url: URL, timeout: TimeInterval = 2.0, completion: @escaping (URL) -> Void) {
        guard isShortened(url) else {
            completion(url)
            return
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        // Real desktop UA so picky shorteners (some corporate ones reject "bot"
        // user-agents) actually return their redirect.
        config.httpAdditionalHeaders = [
            "User-Agent": BrowserUserAgent.safariMacDesktop,
            "Accept": "*/*",
        ]

        attemptExpansion(method: "HEAD", url: url, config: config, timeout: timeout) { resolved in
            // Some shorteners return 405 for HEAD and only redirect on GET.
            // If HEAD didn't yield a different URL, retry once with a ranged GET.
            if resolved.absoluteString == url.absoluteString {
                attemptExpansion(method: "GET", url: url, config: config, timeout: timeout, rangeOnly: true) { fallback in
                    finish(original: url, resolved: fallback, completion: completion)
                }
                return
            }
            finish(original: url, resolved: resolved, completion: completion)
        }
    }

    private static func attemptExpansion(
        method: String,
        url: URL,
        config: URLSessionConfiguration,
        timeout: TimeInterval,
        rangeOnly: Bool = false,
        completion: @escaping (URL) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if rangeOnly {
            // Most servers honor `Range: bytes=0-0` and never send the body.
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }

        let delegate = RedirectCollector()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let task = session.dataTask(with: request) { _, response, _ in
            let resolved = delegate.finalURL ?? response?.url ?? url
            session.finishTasksAndInvalidate()
            completion(resolved)
        }
        task.resume()
    }

    private static func finish(original: URL, resolved: URL, completion: @escaping (URL) -> Void) {
        // SSRF guard: refuse to surface a redirect that points at a non-public
        // host (loopback, RFC1918, link-local, 169.254.169.254, *.local, etc.).
        // Falling back to the original shortener keeps the user in control.
        let safe = URLSafety.isPubliclyRoutable(resolved) ? resolved : original
        completion(safe)
    }
}

private final class RedirectCollector: NSObject, URLSessionTaskDelegate {
    var finalURL: URL?
    /// Hard cap so chained shorteners (`t.co` → `bit.ly` → real) can't loop forever.
    private static let maxHops = 8
    private var hops = 0

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        hops += 1
        if hops > Self.maxHops {
            completionHandler(nil)
            return
        }
        if let url = request.url { finalURL = url }
        completionHandler(request)
    }
}
