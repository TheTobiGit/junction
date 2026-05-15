import Foundation
import AppKit
import Darwin

/// Fetches a small site icon for a host so the picker header can show the destination
/// favicon immediately, without waiting for a full HTML preview parse.
enum HostFaviconFetcher {
    private static let maxBytes = 200_000
    private static let blockedDomainSuffixes = [
        ".corp",
        ".example",
        ".home",
        ".home.arpa",
        ".invalid",
        ".internal",
        ".intranet",
        ".lan",
        ".local",
        ".localhost",
        ".onion",
        ".test",
    ]

    static func fetch(host: String, timeout: TimeInterval = 2.0, completion: @escaping (Data?) -> Void) {
        Task { await fetch(host: host, timeout: timeout, cache: PreviewCache.shared, completion: completion) }
    }

    /// Variant that routes reads/writes through a specific ``PreviewCache`` (e.g. tests with a temp directory).
    static func fetch(host: String, cache: PreviewCache, timeout: TimeInterval = 2.0, completion: @escaping (Data?) -> Void) {
        Task { await fetch(host: host, timeout: timeout, cache: cache, completion: completion) }
    }

    private static func fetch(host: String, timeout: TimeInterval, cache: PreviewCache, completion: @escaping (Data?) -> Void) async {
        guard let remoteHost = remoteIconHost(for: host) else {
            await MainActor.run { completion(nil) }
            return
        }

        if let cached = await cache.favicon(for: remoteHost) {
            await MainActor.run { completion(cached) }
            return
        }

        guard let url = URL(string: "https://icons.duckduckgo.com/ip3/\(remoteHost).ico") else {
            await MainActor.run { completion(nil) }
            return
        }

        let data = await downloadFavicon(from: url, timeout: timeout)
        if let data {
            await cache.storeFavicon(data, for: remoteHost)
        }
        await MainActor.run { completion(data) }
    }

    private static func downloadFavicon(from url: URL, timeout: TimeInterval) async -> Data? {
        await withCheckedContinuation { cont in
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: url) { data, response, _ in
                defer { session.finishTasksAndInvalidate() }
                guard let data,
                      let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      data.count <= maxBytes,
                      NSImage(data: data) != nil
                else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: data)
            }
            task.resume()
        }
    }

    static func remoteIconHost(for host: String) -> String? {
        var normalized = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.hasPrefix("[") && normalized.hasSuffix("]") {
            normalized.removeFirst()
            normalized.removeLast()
        }

        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !normalized.isEmpty,
              normalized.contains("."),
              !isIPAddress(normalized),
              isDomainName(normalized),
              hasPublicLookingSuffix(normalized)
        else {
            return nil
        }

        guard !blockedDomainSuffixes.contains(where: { normalized.hasSuffix($0) }) else {
            return nil
        }

        return normalized
    }

    private static func isDomainName(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count > 1 else { return false }

        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.count <= 63,
                  label.first != "-",
                  label.last != "-"
            else {
                return false
            }

            return label.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "-")
            }
        }
    }

    private static func hasPublicLookingSuffix(_ host: String) -> Bool {
        guard let suffix = host.split(separator: ".").last else { return false }
        return suffix.allSatisfy { $0.isASCII && $0.isLetter }
            || suffix.hasPrefix("xn--")
    }

    private static func isIPAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        if host.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            return true
        }

        var ipv6 = in6_addr()
        if host.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            return true
        }

        return false
    }
}
