import Foundation
import Combine
import CoreGraphics

private struct PickerFrameCodable: Codable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

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
    var chromeTheme: ChromeTheme = .glass
    var accentPreset: AccentPreset = .system
    var pickerStyle: PickerStyle = .tiles
    var pickerFrame: CGRect? = nil
    var trackerOverrides: TrackerOverrides = TrackerOverrides()
    var toursCompleted: [String: Bool] = [:]
    /// Storage key (`LaunchTarget.storageKey`) of the user's favorite
    /// browser or browser profile. The favorite is the named default that
    /// rules and shortcuts can reference symbolically (e.g. "open in
    /// favorite browser"), and it is also rendered at slot 1 of the
    /// picker — setting a favorite reorders `targetOrder` so the favored
    /// key sits at index 0.
    var favoriteTargetKey: String? = nil

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
        case chromeTheme
        case accentPreset
        case pickerStyle
        case pinnedTargetKey // legacy; migrated into favoriteTargetKey on read, not written
        case historyEnabled // legacy; ignored on read, not written
        case pickerFrame
        case trackerOverrides
        case toursCompleted
        case favoriteTargetKey
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
        self.chromeTheme = (try? c.decode(ChromeTheme.self, forKey: .chromeTheme)) ?? .glass
        self.accentPreset = (try? c.decode(AccentPreset.self, forKey: .accentPreset)) ?? .system
        self.pickerStyle = (try? c.decode(PickerStyle.self, forKey: .pickerStyle)) ?? .tiles
        _ = try? c.decode(Bool.self, forKey: .historyEnabled)
        self.pickerFrame = (try? c.decodeIfPresent(PickerFrameCodable.self, forKey: .pickerFrame))?.rect
        self.trackerOverrides = (try? c.decodeIfPresent(TrackerOverrides.self, forKey: .trackerOverrides)) ?? TrackerOverrides()
        self.toursCompleted = (try? c.decodeIfPresent([String: Bool].self, forKey: .toursCompleted)) ?? [:]
        let storedFavorite = try? c.decodeIfPresent(String.self, forKey: .favoriteTargetKey)
        let legacyPinned = try? c.decodeIfPresent(String.self, forKey: .pinnedTargetKey)
        self.favoriteTargetKey = storedFavorite ?? legacyPinned
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cleanURLsBeforeOpening, forKey: .cleanURLsBeforeOpening)
        try c.encode(expandShortenedURLs, forKey: .expandShortenedURLs)
        try c.encode(clipboardWatcherEnabled, forKey: .clipboardWatcherEnabled)
        try c.encode(redirects, forKey: .redirects)
        try c.encode(hiddenTargetKeys, forKey: .hiddenTargetKeys)
        try c.encode(targetOrder, forKey: .targetOrder)
        try c.encode(appSchemes, forKey: .appSchemes)
        try c.encode(hotkeys, forKey: .hotkeys)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(chromeTheme, forKey: .chromeTheme)
        try c.encode(accentPreset, forKey: .accentPreset)
        try c.encode(pickerStyle, forKey: .pickerStyle)
        if let frame = pickerFrame {
            try c.encode(PickerFrameCodable(frame), forKey: .pickerFrame)
        }
        try c.encode(trackerOverrides, forKey: .trackerOverrides)
        try c.encode(toursCompleted, forKey: .toursCompleted)
        try c.encodeIfPresent(favoriteTargetKey, forKey: .favoriteTargetKey)
    }

    /// Sets `favoriteTargetKey` and rewrites `targetOrder` so the favored key is
    /// at index 0. When `key` is nil, clears the favorite without altering
    /// `targetOrder`.
    mutating func setFavoriteTargetKey(_ key: String?) {
        favoriteTargetKey = key
        guard let key else { return }
        var order = targetOrder
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
        targetOrder = order
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

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        let appSupportFolder = bundleID.contains("Preview") ? "JunctionPreview" : "Junction"
        let dir = base.appendingPathComponent(appSupportFolder, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? dir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: self.fileURL),
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

    func setFavoriteTargetKey(_ key: String?) {
        settings.setFavoriteTargetKey(key)
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
