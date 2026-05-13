import Foundation

enum ShortenerExpander {
    static let knownShortenerHosts: Set<String> = [
        "t.co", "bit.ly", "lnkd.in", "buff.ly", "goo.gl", "ow.ly",
        "tinyurl.com", "is.gd", "youtu.be", "wp.me", "amzn.to", "dlvr.it",
        "tr.im", "cutt.ly", "shorturl.at", "rebrand.ly", "short.io",
        "s.id", "t.ly", "go.gle",
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
        config.httpAdditionalHeaders = [
            "User-Agent": "Junction/0.1 (+https://github.com)"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        let delegate = RedirectCollector()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let task = session.dataTask(with: request) { _, response, _ in
            let finalURL = delegate.finalURL ?? response?.url ?? url
            session.finishTasksAndInvalidate()
            completion(finalURL)
        }
        task.resume()
    }
}

private final class RedirectCollector: NSObject, URLSessionTaskDelegate {
    var finalURL: URL?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let url = request.url { finalURL = url }
        completionHandler(request)
    }
}
