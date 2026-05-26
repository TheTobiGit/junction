import Foundation

final class ShortenerExpander {
    static let knownShortenerHosts: Set<String> = [
        "t.co", "bit.ly", "lnkd.in", "buff.ly", "goo.gl", "ow.ly",
        "tinyurl.com", "is.gd", "youtu.be", "wp.me", "amzn.to", "dlvr.it",
        "tr.im", "cutt.ly", "shorturl.at", "rebrand.ly", "short.io",
        "s.id", "t.ly", "go.gle", "bit.do", "soo.gd", "qr.ae",
        "v.gd", "x.gd", "trib.al", "fb.me", "fal.cn", "lnk.to",
        "spoti.fi", "apple.co", "ift.tt",
    ]

    /// Cap on the in-memory expansion cache. Picked to comfortably hold a
    /// long browsing session's worth of distinct shortener URLs without
    /// growing unbounded if the user pastes hundreds of unique links.
    static let defaultCacheCapacity = 256

    static let shared = ShortenerExpander()

    private let networkExpand: (URL, TimeInterval, @escaping (URL) -> Void) -> Void
    private var cache = LRUCache<URL, URL>(capacity: ShortenerExpander.defaultCacheCapacity)
    private let lock = NSLock()

    init(
        capacity: Int = ShortenerExpander.defaultCacheCapacity,
        networkExpand: ((URL, TimeInterval, @escaping (URL) -> Void) -> Void)? = nil
    ) {
        self.cache = LRUCache<URL, URL>(capacity: capacity)
        self.networkExpand = networkExpand ?? ShortenerExpander.defaultNetworkExpand
    }

    // Convenience initializer matching the old signature so existing tests
    // (and `ShortenerExpander.shared`) keep working.
    convenience init(networkExpand: ((URL, TimeInterval, @escaping (URL) -> Void) -> Void)? = nil) {
        self.init(capacity: ShortenerExpander.defaultCacheCapacity, networkExpand: networkExpand)
    }

    internal var cacheSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    internal func seedCache(_ url: URL, resolvedTo resolved: URL) {
        lock.lock()
        cache[url] = resolved
        lock.unlock()
    }

    static func isShortened(_ url: URL) -> Bool {
        guard var host = url.host?.lowercased() else { return false }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return knownShortenerHosts.contains(host)
    }

    func expand(_ url: URL, timeout: TimeInterval = 2.0, completion: @escaping (URL) -> Void) {
        guard Self.isShortened(url) else {
            completion(url)
            return
        }

        lock.lock()
        let cached = cache[url]
        lock.unlock()

        if let cached {
            // SSRF guard applies to cached values: a poisoned cache entry must
            // not bypass the public-routability check.
            let safe = URLSafety.isPubliclyRoutable(cached) ? cached : url
            completion(safe)
            return
        }

        networkExpand(url, timeout) { [weak self] resolved in
            guard let self else { completion(url); return }
            if URLSafety.isPubliclyRoutable(resolved) {
                self.lock.lock()
                self.cache[url] = resolved
                self.lock.unlock()
                completion(resolved)
            } else {
                completion(url)
            }
        }
    }

    private static func defaultNetworkExpand(_ url: URL, _ timeout: TimeInterval, _ completion: @escaping (URL) -> Void) {
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
                    completion(fallback)
                }
                return
            }
            completion(resolved)
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
}

/// Minimal LRU dictionary used to bound the shortener cache. Insert/lookup
/// promote the entry to most-recently-used; once `count` exceeds `capacity`
/// the least-recently-used entry is evicted. Not thread-safe — callers
/// hold an external lock (see `ShortenerExpander.lock`). File-private so the
/// generic name doesn't leak into the app module's namespace.
fileprivate struct LRUCache<Key: Hashable, Value> {
    let capacity: Int
    private var storage: [Key: Value] = [:]
    private var order: [Key] = []

    init(capacity: Int) {
        self.capacity = max(capacity, 1)
    }

    var count: Int { storage.count }

    subscript(key: Key) -> Value? {
        mutating get {
            guard let value = storage[key] else { return nil }
            promote(key)
            return value
        }
        set {
            if let newValue {
                storage[key] = newValue
                promote(key)
                evictIfNeeded()
            } else {
                storage.removeValue(forKey: key)
                order.removeAll { $0 == key }
            }
        }
    }

    private mutating func promote(_ key: Key) {
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
        order.append(key)
    }

    private mutating func evictIfNeeded() {
        while order.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
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
