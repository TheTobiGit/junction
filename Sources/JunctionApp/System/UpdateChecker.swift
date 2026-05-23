import AppKit
import Combine
import Foundation

/// Checks the GitHub Releases API for newer versions of Junction.
///
/// We use a tiny inline JSON decoder against a single endpoint instead of
/// pulling in Sparkle. Trade-off: no in-app delta updates, but zero new
/// dependencies and zero new code-signing requirements (Sparkle wants its
/// own EdDSA signature on the appcast).
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate(currentVersion: String)
        case updateAvailable(latestVersion: String, htmlURL: URL, downloadURL: URL?)
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckedAt: Date?

    private static let endpoint = URL(string: "https://api.github.com/repos/TheTobiGit/junction/releases/latest")!

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func check(silent: Bool = false) {
        if case .checking = state { return }
        state = .checking
        Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await self.fetchLatestRelease()
                let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                let current = self.currentVersion
                self.lastCheckedAt = Date()
                if Self.isNewer(latest: latest, than: current) {
                    let download = release.assets.first(where: { $0.name.hasSuffix("-macos.zip") && !$0.name.contains("cli") })?.browser_download_url
                    self.state = .updateAvailable(latestVersion: latest, htmlURL: release.html_url, downloadURL: download)
                } else {
                    self.state = .upToDate(currentVersion: current)
                }
            } catch {
                if silent {
                    self.state = .idle
                } else {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func openLatestRelease() {
        if case .updateAvailable(_, let htmlURL, _) = state {
            NSWorkspace.shared.open(htmlURL)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/TheTobiGit/junction/releases/latest")!)
        }
    }

    private struct GHRelease: Decodable {
        let tag_name: String
        let html_url: URL
        let assets: [GHAsset]
    }

    private struct GHAsset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    private func fetchLatestRelease() async throws -> GHRelease {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Junction/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "UpdateChecker", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(http.statusCode)"])
        }
        return try JSONDecoder().decode(GHRelease.self, from: data)
    }

    /// Compares dot-separated semver prefixes numerically. Strips leading "v"
    /// and any pre-release suffix after the first "-".
    static func isNewer(latest: String, than current: String) -> Bool {
        compare(normalize(latest), normalize(current)) == .orderedDescending
    }

    private static func normalize(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let core = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        return core.split(separator: ".").compactMap { Int($0) }
    }

    private static func compare(_ a: [Int], _ b: [Int]) -> ComparisonResult {
        let count = max(a.count, b.count)
        for i in 0..<count {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x > y { return .orderedDescending }
            if x < y { return .orderedAscending }
        }
        return .orderedSame
    }
}
