import Foundation
import Combine

extension Notification.Name {
    static let junctionRulesChanged = Notification.Name("junctionRulesChanged")
}

final class RulesStore {
    static let shared = RulesStore()

    private let queue = DispatchQueue(label: "dev.gideonsarfo.Junction.rules")
    private var source: DispatchSourceFileSystemObject?
    private var lastWriteByUs: Date?

    let fileURL: URL
    private(set) var file: RulesFile

    var rules: RulesFile { file }

    private init() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".config/junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("rules.json")

        self.file = Self.load(from: fileURL) ?? Self.migrateFromLegacy() ?? RulesFile()

        if !fm.fileExists(atPath: fileURL.path) {
            writeToDisk(file)
        }

        startWatching()
    }

    func match(host: String, context: RouteContext) -> RuleAction {
        for rule in file.rules where rule.enabled {
            if !rule.host.matches(host) { continue }
            if let condition = rule.when, !condition.matches(context: context) { continue }
            return rule.action
        }
        return file.fallback
    }

    func remember(target: LaunchTarget, forHost host: String) {
        let newRule = DomainRule(host: .equals(host), action: .open(target))
        update { f in
            f.rules.removeAll { existing in
                if case .equals(let h) = existing.host, h.lowercased() == host.lowercased() {
                    return true
                }
                return false
            }
            f.rules.insert(newRule, at: 0)
        }
    }

    func addRule(host: HostMatch, action: RuleAction) {
        update { f in
            let key = "\(host.kindLabel):\(host.displayValue.lowercased())"
            f.rules.removeAll { "\($0.host.kindLabel):\($0.host.displayValue.lowercased())" == key }
            f.rules.insert(DomainRule(host: host, action: action), at: 0)
        }
    }

    func removeRule(hostValue: String) -> Bool {
        let key = hostValue.lowercased()
        var removed = false
        update { f in
            let before = f.rules.count
            f.rules.removeAll { $0.host.displayValue.lowercased() == key }
            removed = f.rules.count != before
        }
        return removed
    }

    func remove(ruleID: UUID) {
        update { f in f.rules.removeAll { $0.id == ruleID } }
    }

    func setFallback(_ action: RuleAction) {
        update { f in f.fallback = action }
    }

    func importRecipe(_ recipe: RuleRecipe) {
        update { f in
            var existingKeys = Set(f.rules.map { "\($0.host.kindLabel):\($0.host.displayValue.lowercased())" })
            for rule in recipe.rules {
                let key = "\(rule.host.kindLabel):\(rule.host.displayValue.lowercased())"
                if existingKeys.insert(key).inserted {
                    f.rules.append(rule)
                }
            }
        }
    }

    private func update(_ mutation: (inout RulesFile) -> Void) {
        var next = file
        mutation(&next)
        file = next
        writeToDisk(next)
        NotificationCenter.default.post(name: .junctionRulesChanged, object: nil)
    }

    private func writeToDisk(_ rules: RulesFile) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
        lastWriteByUs = Date()
    }

    private static func load(from url: URL) -> RulesFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RulesFile.self, from: data)
    }

    private static func migrateFromLegacy() -> RulesFile? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let legacy = base.appendingPathComponent("Junction/rules.json")
        guard let data = try? Data(contentsOf: legacy) else { return nil }

        struct LegacyRules: Codable {
            var targets: [String: LaunchTarget] = [:]
            var fallback: LaunchTarget? = nil
        }
        struct V0Rules: Codable {
            var domains: [String: String] = [:]
            var fallbackBundleID: String? = nil
        }

        if let parsed = try? JSONDecoder().decode(LegacyRules.self, from: data) {
            var file = RulesFile()
            file.rules = parsed.targets
                .sorted { $0.key < $1.key }
                .map { DomainRule(host: .equals($0.key), action: .open($0.value)) }
            file.fallback = parsed.fallback.map { .open($0) } ?? .ask
            return file
        }
        if let parsed = try? JSONDecoder().decode(V0Rules.self, from: data) {
            var file = RulesFile()
            file.rules = parsed.domains
                .sorted { $0.key < $1.key }
                .map { DomainRule(host: .equals($0.key), action: .open(.app(bundleID: $0.value))) }
            file.fallback = parsed.fallbackBundleID.map { .open(.app(bundleID: $0)) } ?? .ask
            return file
        }
        return nil
    }

    private func startWatching() {
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd != -1 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleFileEvent(source: source)
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.source = source
    }

    private func handleFileEvent(source: DispatchSourceFileSystemObject) {
        let mask = source.data
        if mask.contains(.delete) || mask.contains(.rename) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.restartWatching()
                self?.reloadFromDisk()
            }
            return
        }
        if let last = lastWriteByUs, Date().timeIntervalSince(last) < 0.3 { return }
        DispatchQueue.main.async { [weak self] in self?.reloadFromDisk() }
    }

    private func restartWatching() {
        source?.cancel()
        source = nil
        startWatching()
    }

    private func reloadFromDisk() {
        guard let next = Self.load(from: fileURL) else { return }
        file = next
        NotificationCenter.default.post(name: .junctionRulesChanged, object: nil)
    }

    static func normalizedHost(for url: URL) -> String? {
        guard var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
