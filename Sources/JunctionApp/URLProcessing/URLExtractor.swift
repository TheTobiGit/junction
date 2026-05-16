import Foundation

/// Pulls every plausible URL from arbitrary text — used by the clipboard
/// watcher when a user pastes a list of links instead of a single one.
enum URLExtractor {
    private static let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    /// Extracts unique http/https URLs in order of appearance, preserving the
    /// first occurrence when the same link shows up twice.
    static func extract(from text: String, max: Int = 64) -> [URL] {
        guard !text.isEmpty, let detector else { return [] }
        let nsText = text as NSString
        let matches = detector.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        var seen = Set<String>()
        var out: [URL] = []
        for match in matches {
            guard let url = match.url else { continue }
            guard let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { continue }
            let key = url.absoluteString
            if seen.insert(key).inserted {
                out.append(url)
                if out.count >= max { break }
            }
        }
        return out
    }
}
