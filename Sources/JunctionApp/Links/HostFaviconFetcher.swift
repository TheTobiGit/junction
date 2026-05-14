import Foundation
import AppKit

/// Fetches a small site icon for a host so the picker header can show the destination
/// favicon immediately, without waiting for a full HTML preview parse.
enum HostFaviconFetcher {
    private static let maxBytes = 200_000

    static func fetch(host: String, timeout: TimeInterval = 2.0, completion: @escaping (Data?) -> Void) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed != "localhost" else {
            completion(nil)
            return
        }

        guard let url = URL(string: "https://icons.duckduckgo.com/ip3/\(trimmed).ico") else {
            completion(nil)
            return
        }

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
                completion(nil)
                return
            }
            completion(data)
        }
        task.resume()
    }
}
