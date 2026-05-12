import AppKit
import SwiftUI
import JunctionCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var picker: PickerPanelController?
    private var prefs: PreferencesWindowController?
    private var pendingURLs: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(
            openPreferences: { [weak self] in self?.showPreferences() }
        )
        _ = FrontmostTracker.shared
        ClipboardWatcher.shared.updateEnabledState()
        startAgentServer()
        flushPendingURLs()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AgentServer.shared.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handleIncoming(url) }
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard
            let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: raw)
        else { return }
        handleIncoming(url)
    }

    private func handleIncoming(_ url: URL) {
        if url.scheme?.lowercased() == "junction" {
            handleJunctionScheme(url)
            return
        }
        route(url)
    }

    private func handleJunctionScheme(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let action = comps.host ?? comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let items = (comps.queryItems ?? []).reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value }

        switch action.lowercased() {
        case "open":
            guard let rawURL = items["url"], let target = URL(string: rawURL) else { return }
            let explicitTargetKey = items["target"] ?? items["in"]
            let ask = items["ask"] == "1" || items["ask"]?.lowercased() == "true"
            let clean = items["clean"].flatMap { $0 == "1" || $0.lowercased() == "true" }

            if ask {
                showPicker(for: target)
                return
            }

            if let key = explicitTargetKey,
               let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) {
                let shouldClean = clean ?? SettingsStore.shared.settings.cleanURLsBeforeOpening
                let finalURL = shouldClean ? URLTransformers.default.run(target) : target
                URLOpener.open(finalURL, with: option) { _ in
                    LinkLog.shared.record(LinkLogEntry(
                        url: finalURL, target: option,
                        source: FrontmostTracker.shared.lastNonJunction,
                        cleaned: shouldClean
                    ))
                }
                return
            }

            route(target)

        case "savelater":
            guard let rawURL = items["url"], let target = URL(string: rawURL) else { return }
            LinkInbox.shared.add(url: target, source: FrontmostTracker.shared.lastNonJunction)

        case "preferences":
            showPreferences()

        case "history":
            menuBar?.showHistoryWindow()

        case "batch":
            menuBar?.showBatchWindow()

        default:
            break
        }
    }

    private func startAgentServer() {
        AgentServer.shared.onRequest = { [weak self] req in
            guard let self else { return .error("agent unavailable") }
            return self.handleAgentRequest(req)
        }
        AgentServer.shared.start()
    }

    private func handleAgentRequest(_ request: AgentRequest) -> AgentResponse {
        switch request {
        case .ping:
            return .pong
        case .open(let raw, let targetKey, let ask, let clean):
            guard let url = URL(string: raw) else { return .error("invalid URL: \(raw)") }
            DispatchQueue.main.async { [weak self] in
                self?.routeAgent(url: url, targetKey: targetKey, ask: ask, clean: clean)
            }
            return .ok(message: nil)
        case .listRules:
            let rules = RulesStore.shared.rules.rules.map { rule -> AgentRuleSummary in
                let actionLabel: String
                switch rule.action {
                case .ask: actionLabel = "ask"
                case .open(let t): actionLabel = t.storageKey
                }
                return AgentRuleSummary(
                    hostKind: rule.host.kindLabel,
                    hostValue: rule.host.displayValue,
                    action: actionLabel
                )
            }
            return .rules(rules)
        case .listTargets:
            let targets = LaunchOptionDiscovery.options().map {
                AgentTargetSummary(key: $0.target.storageKey, displayName: $0.displayName)
            }
            return .targets(targets)
        case .addRule(let kind, let value, let targetKey):
            let hostMatch: HostMatch
            switch kind {
            case "equals": hostMatch = .equals(value)
            case "suffix": hostMatch = .suffix(value)
            case "regex": hostMatch = .regex(value)
            default: return .error("invalid host kind: \(kind) (use equals, suffix, or regex)")
            }
            let action: RuleAction
            if let key = targetKey {
                guard let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) else {
                    return .error("unknown target: \(key) (use `junction targets` to list)")
                }
                action = .open(option.target)
            } else {
                action = .ask
            }
            RulesStore.shared.addRule(host: hostMatch, action: action)
            return .ok(message: "added rule for \(value)")
        case .removeRule(let value):
            let removed = RulesStore.shared.removeRule(hostValue: value)
            return removed ? .ok(message: "removed rule for \(value)") : .error("no rule matched \(value)")
        }
    }

    @MainActor
    private func routeAgent(url: URL, targetKey: String?, ask: Bool, clean: Bool?) {
        if ask {
            showPicker(for: url)
            return
        }

        let shouldClean = clean ?? SettingsStore.shared.settings.cleanURLsBeforeOpening
        let finalURL = shouldClean ? URLTransformers.default.run(url) : url

        if let key = targetKey,
           let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) {
            URLOpener.open(finalURL, with: option)
            return
        }

        route(url)
    }

    private func route(_ url: URL) {
        guard menuBar != nil else {
            pendingURLs.append(url)
            return
        }

        if SettingsStore.shared.settings.expandShortenedURLs,
           ShortenerExpander.isShortened(url) {
            ShortenerExpander.expand(url) { [weak self] expanded in
                DispatchQueue.main.async {
                    self?.routeAfterExpansion(original: url, resolved: expanded)
                }
            }
            return
        }

        routeAfterExpansion(original: url, resolved: url)
    }

    private func routeAfterExpansion(original: URL, resolved: URL) {
        let context = RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )

        let host = RulesStore.normalizedHost(for: resolved)
        let action: RuleAction = host.map { RulesStore.shared.match(host: $0, context: context) } ?? .ask

        switch action {
        case .open(let target):
            guard let option = resolve(target: target) else {
                showPicker(for: resolved, context: context)
                return
            }
            let cleaned = SettingsStore.shared.settings.cleanURLsBeforeOpening
            let urlToOpen = cleaned ? URLTransformers.default.run(resolved) : resolved
            URLOpener.open(urlToOpen, with: option) { success in
                if success {
                    LinkLog.shared.record(LinkLogEntry(
                        url: urlToOpen,
                        target: option,
                        source: context.source,
                        cleaned: cleaned
                    ))
                    UndoNotifier.shared.announce(
                        url: urlToOpen,
                        option: option,
                        alternatives: LaunchOptionDiscovery.options()
                    )
                }
            }
        case .ask:
            showPicker(for: resolved, context: context)
        }
    }

    private func resolve(target: LaunchTarget) -> LaunchOption? {
        let options = LaunchOptionDiscovery.options()
        if let match = options.first(where: { $0.target == target }) {
            return match
        }
        return options.first { $0.browser.bundleID == target.bundleID }
    }

    private func flushPendingURLs() {
        let urls = pendingURLs
        pendingURLs.removeAll()
        for url in urls { route(url) }
    }

    private func showPicker(for url: URL, context: RouteContext? = nil) {
        let controller = picker ?? PickerPanelController()
        picker = controller
        let ctx = context ?? RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )
        controller.present(url: url, context: ctx)
    }

    private func showPreferences() {
        let controller = prefs ?? PreferencesWindowController()
        prefs = controller
        controller.show()
    }
}
