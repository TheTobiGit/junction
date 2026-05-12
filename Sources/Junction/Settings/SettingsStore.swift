import Foundation
import Combine

struct JunctionSettings: Codable {
    var cleanURLsBeforeOpening: Bool = true
    var expandShortenedURLs: Bool = true
    var clipboardWatcherEnabled: Bool = false
    var redirects: [DomainRedirect] = DefaultRedirects.all
    var hiddenTargetKeys: [String] = []
    var targetOrder: [String] = []

    enum CodingKeys: String, CodingKey {
        case cleanURLsBeforeOpening
        case expandShortenedURLs
        case clipboardWatcherEnabled
        case redirects
        case hiddenTargetKeys
        case targetOrder
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cleanURLsBeforeOpening = (try? c.decode(Bool.self, forKey: .cleanURLsBeforeOpening)) ?? true
        self.expandShortenedURLs = (try? c.decode(Bool.self, forKey: .expandShortenedURLs)) ?? true
        self.clipboardWatcherEnabled = (try? c.decode(Bool.self, forKey: .clipboardWatcherEnabled)) ?? false
        self.redirects = (try? c.decode([DomainRedirect].self, forKey: .redirects)) ?? DefaultRedirects.all
        self.hiddenTargetKeys = (try? c.decode([String].self, forKey: .hiddenTargetKeys)) ?? []
        self.targetOrder = (try? c.decode([String].self, forKey: .targetOrder)) ?? []
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: JunctionSettings {
        didSet {
            persist()
            ClipboardWatcher.shared.updateEnabledState()
        }
    }

    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(JunctionSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = JunctionSettings()
        }
    }

    func isHidden(_ key: String) -> Bool {
        settings.hiddenTargetKeys.contains(key)
    }

    func setHidden(_ hidden: Bool, for key: String) {
        var keys = settings.hiddenTargetKeys
        if hidden {
            if !keys.contains(key) { keys.append(key) }
        } else {
            keys.removeAll { $0 == key }
        }
        settings.hiddenTargetKeys = keys
    }

    func setTargetOrder(_ order: [String]) {
        settings.targetOrder = order
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
