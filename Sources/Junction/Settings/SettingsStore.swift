import Foundation
import Combine

struct HotkeyBinding: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var enabled: Bool

    static let none = HotkeyBinding(keyCode: 0, modifiers: 0, enabled: false)
}

struct HotkeySettings: Codable, Hashable {
    var summonPicker: HotkeyBinding
    var rerouteLast: HotkeyBinding
    var pasteAndOpen: HotkeyBinding

    static let defaults = HotkeySettings(
        summonPicker: .none,
        rerouteLast: .none,
        pasteAndOpen: .none
    )
}

struct JunctionSettings: Codable {
    var cleanURLsBeforeOpening: Bool = true
    var expandShortenedURLs: Bool = true
    var clipboardWatcherEnabled: Bool = false
    var redirects: [DomainRedirect] = DefaultRedirects.all
    var hiddenTargetKeys: [String] = []
    var targetOrder: [String] = []
    var appSchemes: [AppSchemeRewrite] = AppSchemeCatalog.defaults
    var hotkeys: HotkeySettings = .defaults
    var hasCompletedOnboarding: Bool = false

    enum CodingKeys: String, CodingKey {
        case cleanURLsBeforeOpening
        case expandShortenedURLs
        case clipboardWatcherEnabled
        case redirects
        case hiddenTargetKeys
        case targetOrder
        case appSchemes
        case hotkeys
        case hasCompletedOnboarding
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

        let storedSchemes = (try? c.decode([AppSchemeRewrite].self, forKey: .appSchemes)) ?? []
        self.appSchemes = JunctionSettings.mergeAppSchemes(stored: storedSchemes)

        self.hotkeys = (try? c.decode(HotkeySettings.self, forKey: .hotkeys)) ?? .defaults
        self.hasCompletedOnboarding = (try? c.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
    }

    static func mergeAppSchemes(stored: [AppSchemeRewrite]) -> [AppSchemeRewrite] {
        let storedByID = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        var merged: [AppSchemeRewrite] = []
        var seen = Set<String>()
        for builtin in AppSchemeCatalog.defaults {
            if let existing = storedByID[builtin.id] {
                var updated = builtin
                updated.enabled = existing.enabled
                merged.append(updated)
            } else {
                merged.append(builtin)
            }
            seen.insert(builtin.id)
        }
        for entry in stored where !seen.contains(entry.id) {
            merged.append(entry)
        }
        return merged
    }
}

extension Notification.Name {
    static let junctionHotkeysChanged = Notification.Name("junctionHotkeysChanged")
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var settings: JunctionSettings {
        didSet {
            persist()
            ClipboardWatcher.shared.updateEnabledState()
            if oldValue.hotkeys != settings.hotkeys {
                NotificationCenter.default.post(name: .junctionHotkeysChanged, object: nil)
            }
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

    func setAppSchemeEnabled(id: String, enabled: Bool) {
        var schemes = settings.appSchemes
        guard let idx = schemes.firstIndex(where: { $0.id == id }) else { return }
        schemes[idx].enabled = enabled
        settings.appSchemes = schemes
    }

    func setHotkey(_ binding: HotkeyBinding, for keyPath: WritableKeyPath<HotkeySettings, HotkeyBinding>) {
        settings.hotkeys[keyPath: keyPath] = binding
    }

    func markOnboardingComplete() {
        settings.hasCompletedOnboarding = true
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
