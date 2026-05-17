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

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.file = Self.load(from: fileURL) ?? RulesFile()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            writeToDisk(file)
        }
    }

    struct RuleMatch {
        let action: RuleAction
        let rule: DomainRule?
    }

    func match(url: URL, context: RouteContext) -> RuleMatch {
        let host = RulesStore.normalizedHost(for: url)
        for rule in file.rules where rule.matches(url: url, host: host, context: context) {
            return RuleMatch(action: rule.action, rule: rule)
        }
        return RuleMatch(action: file.fallback, rule: nil)
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

    func addRule(host: HostMatch, action: RuleAction, cleanOverride: Bool? = nil) {
        addRule(DomainRule(host: host, action: action, cleanOverride: cleanOverride))
    }

    /// Inserts a fully-constructed rule at the top of the list. Replaces any
    /// existing rule with the same `dedupKey` so the new shape wins (URL
    /// rules dedupe against URL rules, host rules against host rules — they
    /// never collide on one another). Used by the Add-Rule sheet, which
    /// constructs rules with optional fields the simpler overload doesn't
    /// take (currently just `urlEquals`; later `path`/`when`/etc.).
    func addRule(_ rule: DomainRule) {
        update { f in
            let key = rule.dedupKey
            f.rules.removeAll { $0.dedupKey == key }
            f.rules.insert(rule, at: 0)
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

    /// Mutates a single rule in place, identified by its `id`. Used by the
    /// Rules UI to flip per-rule fields (like `cleanOverride`) without
    /// regenerating UUIDs or losing position.
    func updateRule(id: UUID, _ mutation: (inout DomainRule) -> Void) {
        update { f in
            guard let idx = f.rules.firstIndex(where: { $0.id == id }) else { return }
            mutation(&f.rules[idx])
        }
    }

    /// Reorders rules in place. Rule ordering is semantically meaningful —
    /// `match(url:context:)` returns the **first** matching rule, so moving
    /// a more-specific rule above a broader one changes routing behavior.
    /// Signature matches SwiftUI's `ForEach.onMove(perform:)` so the Rules
    /// tab can wire this up directly.
    func moveRule(from source: IndexSet, to destination: Int) {
        update { f in
            f.rules.move(fromOffsets: source, toOffset: destination)
        }
    }

    func setFallback(_ action: RuleAction) {
        update { f in f.fallback = action }
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
        // DNS allows fully-qualified names with a trailing dot
        // ("example.com."); resolvers strip it. We must too, otherwise rules
        // keyed on `example.com` silently miss URLs that arrive with the dot.
        while host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        // Fold xn-- labels to their Unicode form so a rule keyed on either side
        // matches both. Rules are stored as the user typed them; matching
        // canonicalizes both URL host and rule host to the same Unicode form.
        return IDNA.toUnicode(host: host)
    }
}
