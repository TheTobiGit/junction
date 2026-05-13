import AppKit
import SwiftUI
import JunctionCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var picker: PickerPanelController?
    private var prefs: PreferencesWindowController?
    private var onboarding: OnboardingWindowController?
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
            openPreferences: { [weak self] in self?.showPreferences() },
            openOnboarding: { [weak self] in self?.showOnboarding() }
        )
        _ = FrontmostTracker.shared
        ClipboardWatcher.shared.updateEnabledState()
        startAgentServer()
        configureHotkeys()
        flushPendingURLs()
        maybeShowOnboarding()
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
            let incognito = items["private"] == "1" || items["private"]?.lowercased() == "true" || items["incognito"] == "1"

            if ask {
                showPicker(for: target)
                return
            }

            if let key = explicitTargetKey,
               let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) {
                let shouldClean = clean ?? SettingsStore.shared.settings.cleanURLsBeforeOpening
                let finalURL = shouldClean ? URLTransformers.default.run(target) : target
                URLOpener.open(finalURL, with: option, incognito: incognito) { success in
                    if success { LastURLStore.shared.recordRouted(finalURL) }
                }
                return
            }

            route(target)

        case "preferences":
            showPreferences()

        case "onboarding":
            showOnboarding()

        default:
            break
        }
    }

    private func configureHotkeys() {
        GlobalHotkeyManager.shared.onAction = { [weak self] action in
            self?.handleHotkey(action)
        }
        GlobalHotkeyManager.shared.reload(from: SettingsStore.shared.settings.hotkeys)

        NotificationCenter.default.addObserver(
            forName: .junctionHotkeysChanged,
            object: nil,
            queue: .main
        ) { _ in
            GlobalHotkeyManager.shared.reload(from: SettingsStore.shared.settings.hotkeys)
        }
    }

    private func handleHotkey(_ action: HotkeyAction) {
        switch action {
        case .summonPicker:
            summonPickerForClipboardOrLast()
        case .rerouteLast:
            if let url = LastURLStore.shared.mostRecent {
                showPicker(for: url)
            }
        case .pasteAndOpen:
            if let url = clipboardURL() {
                route(url)
            }
        }
    }

    private func summonPickerForClipboardOrLast() {
        if let url = clipboardURL() {
            showPicker(for: url)
        } else if let url = LastURLStore.shared.mostRecent {
            showPicker(for: url)
        }
    }

    private func clipboardURL() -> URL? {
        guard let raw = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        if raw.contains(".") {
            return URL(string: "https://" + raw)
        }
        return nil
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
                AgentRuleSummary(
                    hostKind: rule.host.kindLabel,
                    hostValue: rule.host.displayValue,
                    action: agentActionLabel(rule.action)
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
                if key == "__block__" { action = .block }
                else if key.hasPrefix("incognito:") {
                    let stripped = String(key.dropFirst("incognito:".count))
                    guard let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == stripped }) else {
                        return .error("unknown target: \(stripped)")
                    }
                    action = .openIncognito(option.target)
                } else if key.hasPrefix("scheme:") {
                    action = .appScheme(String(key.dropFirst("scheme:".count)))
                } else {
                    guard let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) else {
                        return .error("unknown target: \(key) (use `junction targets` to list)")
                    }
                    action = .open(option.target)
                }
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

    private func agentActionLabel(_ action: RuleAction) -> String {
        switch action {
        case .ask: return "ask"
        case .block: return "block"
        case .open(let t): return t.storageKey
        case .openIncognito(let t): return "incognito:\(t.storageKey)"
        case .appScheme(let s): return "scheme:\(s)"
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
            URLOpener.open(finalURL, with: option) { success in
                if success { LastURLStore.shared.recordRouted(finalURL) }
            }
            return
        }

        route(url)
    }

    private func route(_ url: URL) {
        guard menuBar != nil else {
            pendingURLs.append(url)
            return
        }

        if let rewritten = AppSchemeRewriter.rewrite(
            url,
            using: SettingsStore.shared.settings.appSchemes
        ) {
            NSWorkspace.shared.open(rewritten)
            LastURLStore.shared.recordRouted(url)
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

        if let rewritten = AppSchemeRewriter.rewrite(
            resolved,
            using: SettingsStore.shared.settings.appSchemes
        ) {
            NSWorkspace.shared.open(rewritten)
            LastURLStore.shared.recordRouted(resolved)
            return
        }

        let match = RulesStore.shared.match(url: resolved, context: context)

        if match.rule?.alsoCopyCleaned == true {
            copyCleaned(resolved)
        }

        switch match.action {
        case .block:
            showBlockedNotice(resolved)
            return
        case .appScheme(let scheme):
            let deepLink = buildSchemeURL(scheme: scheme, from: resolved)
            if let deepLink {
                NSWorkspace.shared.open(deepLink)
                LastURLStore.shared.recordRouted(resolved)
            } else {
                showPicker(for: resolved, context: context)
            }
            return
        case .open(let target):
            guard let option = resolve(target: target) else {
                showPicker(for: resolved, context: context)
                return
            }
            let cleaned = SettingsStore.shared.settings.cleanURLsBeforeOpening
            let urlToOpen = cleaned ? URLTransformers.default.run(resolved) : resolved
            URLOpener.open(urlToOpen, with: option) { success in
                if success {
                    LastURLStore.shared.recordRouted(urlToOpen)
                    UndoNotifier.shared.announce(
                        url: urlToOpen,
                        option: option,
                        alternatives: LaunchOptionDiscovery.options()
                    )
                }
            }
        case .openIncognito(let target):
            guard let option = resolve(target: target) else {
                showPicker(for: resolved, context: context)
                return
            }
            let cleaned = SettingsStore.shared.settings.cleanURLsBeforeOpening
            let urlToOpen = cleaned ? URLTransformers.default.run(resolved) : resolved
            URLOpener.open(urlToOpen, with: option, incognito: true) { success in
                if success { LastURLStore.shared.recordRouted(urlToOpen) }
            }
        case .ask:
            showPicker(for: resolved, context: context)
        }
    }

    private func buildSchemeURL(scheme: String, from url: URL) -> URL? {
        if scheme.contains("://") {
            var output = scheme
            output = output.replacingOccurrences(of: "{host}", with: url.host ?? "")
            output = output.replacingOccurrences(of: "{path}", with: url.path)
            output = output.replacingOccurrences(of: "{query}", with: url.query ?? "")
            output = output.replacingOccurrences(of: "{url}", with: url.absoluteString)
            return URL(string: output)
        }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        comps.scheme = scheme
        return comps.url
    }

    private func showBlockedNotice(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "Link blocked"
        alert.informativeText = url.absoluteString
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func copyCleaned(_ url: URL) {
        let cleaned = URLTransformers.default.run(url)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cleaned.absoluteString, forType: .string)
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

    private func showOnboarding() {
        let controller = onboarding ?? OnboardingWindowController()
        onboarding = controller
        controller.show()
    }

    private func maybeShowOnboarding() {
        if !SettingsStore.shared.settings.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showOnboarding()
            }
        }
    }
}

