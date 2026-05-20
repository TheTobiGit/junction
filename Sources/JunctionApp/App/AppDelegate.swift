import AppKit
import SwiftUI
import JunctionCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var picker: PickerPanelController?
    private var prefs: PreferencesWindowController?
    private var onboarding: OnboardingWindowController?
    private var postDefaultTour: PostDefaultTourOverlayController?
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
            openPreferences: { [weak self] focus in self?.showPreferences(focus: focus) },
            routeURL: { [weak self] url in self?.route(url) }
        )
        _ = FrontmostTracker.shared
        ClipboardWatcher.shared.updateEnabledState()
        startAgentServer()
        configureHotkeys()
        observeWorkspaceForAppSchemeCache()
        observeWorkspaceForPostDefaultTour()
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
                let globalSettings = SettingsStore.shared.settings
                let globalTrace = URLTransformers.default.runTraced(target)
                // junction://open?clean=… is an explicit user request and
                // wins. Without it, fall through to the matching rule's
                // `cleanOverride` so a "Never clean" pin on the host applies
                // even when an explicit target was passed.
                let context = RouteContext(
                    source: FrontmostTracker.shared.lastNonJunction,
                    focus: FocusTracker.current()
                )
                let match = RulesStore.shared.match(url: globalTrace.final, context: context)
                let trace: URLTransformResult
                if let ruleOverrides = match.rule?.trackerOverrides {
                    trace = URLTransformers.pipeline(
                        globalOverrides: globalSettings.trackerOverrides,
                        ruleOverrides: ruleOverrides
                    ).runTraced(target)
                } else {
                    trace = globalTrace
                }
                let shouldClean: Bool
                if let explicit = clean {
                    shouldClean = explicit
                } else {
                    shouldClean = DomainRule.resolveCleanFlag(
                        rule: match.rule,
                        globalEnabled: globalSettings.cleanURLsBeforeOpening
                    )
                }
                let finalURL = shouldClean ? trace.final : target
                if incognito, !supportsPrivate(option) {
                    showPicker(for: target)
                    return
                }
                URLOpener.open(finalURL, with: option, incognito: incognito) { success in
                    if success {
                        LastURLStore.shared.recordRouted(finalURL)
                        RoutingHistory.shared.record(
                            originalURL: target,
                            result: trace,
                            outcome: incognito ? .openedIncognito : .opened,
                            targetBundleID: option.browser.bundleID,
                            ruleLabel: "junction-scheme",
                            openedURL: finalURL,
                            sourceBundleID: FrontmostTracker.shared.lastNonJunction?.bundleID,
                            targetStorageKey: option.target.storageKey
                        )
                    }
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

    private func observeWorkspaceForPostDefaultTour() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard activated?.bundleIdentifier == Bundle.main.bundleIdentifier else { return }
            self?.maybeShowPostDefaultTour()
        }
    }

    private func maybeShowPostDefaultTour() {
        let settings = SettingsStore.shared.settings
        guard settings.toursCompleted["postDefault"] != true else { return }
        let status = DefaultWebBrowserStatus.current
        guard OnboardingTourManager.shouldShowPostDefaultTour(settings: settings, status: status) else { return }
        let controller = postDefaultTour ?? PostDefaultTourOverlayController()
        postDefaultTour = controller
        controller.onDismiss = { [weak self] in
            OnboardingTourManager.markPostDefaultTourComplete()
            self?.postDefaultTour = nil
        }
        controller.show()
    }

    /// Drop the cached `bundleID → installed?` map whenever the workspace
    /// notices a new app being launched or a volume mounting; otherwise users
    /// who install Slack/Linear/Figma mid-session keep getting "open in browser"
    /// until they restart Junction.
    private func observeWorkspaceForAppSchemeCache() {
        let center = NSWorkspace.shared.notificationCenter
        let token: (Notification) -> Void = { _ in
            AppSchemeRewriter.refreshCache()
        }
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: token)
        center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main, using: token)
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
                    hostKind: rule.kindLabel,
                    hostValue: rule.displayValue,
                    action: agentActionLabel(rule.action),
                    cleanOverride: rule.cleanOverride
                )
            }
            return .rules(rules)
        case .listTargets:
            let targets = LaunchOptionDiscovery.options().map {
                AgentTargetSummary(key: $0.target.storageKey, displayName: $0.displayName)
            }
            return .targets(targets)
        case .addRule(let kind, let value, let targetKey, let cleanOverride, let pathKind, let pathValue, let sourceApps):
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
                    guard supportsPrivate(option) else {
                        return .error("target does not support private/incognito windows: \(stripped)")
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
            let pathMatch: URLPathMatch?
            if let pk = pathKind, let pv = pathValue, !pv.isEmpty {
                guard let built = URLPathMatch.from(kind: pk, value: pv) else {
                    return .error("invalid path kind: \(pk) (use prefix, contains, regex, or glob)")
                }
                pathMatch = built
            } else {
                pathMatch = nil
            }
            var rule = DomainRule(host: hostMatch, action: action, cleanOverride: cleanOverride)
            rule.path = pathMatch
            if let apps = sourceApps, !apps.isEmpty {
                rule.when = RuleCondition(sourceApp: apps)
            }
            RulesStore.shared.addRule(rule)
            return .ok(message: "added rule for \(value)")
        case .removeRule(let value):
            let removed = RulesStore.shared.removeRule(hostValue: value)
            return removed ? .ok(message: "removed rule for \(value)") : .error("no rule matched \(value)")
        case .inspect(let raw):
            guard let url = URL(string: raw) else { return .error("invalid URL: \(raw)") }
            let trace = URLTransformers.default.runTraced(url)
            let flags = URLRiskAssessor.assess(trace.final)
            let result = AgentInspectResult(
                original: trace.original.absoluteString,
                cleaned: trace.final.absoluteString,
                steps: trace.steps.map {
                    AgentInspectStep(identifier: $0.identifier, after: $0.after.absoluteString)
                },
                flags: flags.map {
                    AgentInspectFlag(level: $0.level.label, title: $0.title, detail: $0.detail)
                },
                strippedTrackerParams: URLDiff.strippedTrackerParams(in: trace)
            )
            return .inspectResult(result)
        case .listHistory(let limit):
            let cap = min(max(limit, 1), RoutingHistory.maxEntries)
            let entries = Array(RoutingHistory.shared.entries.prefix(cap))
            return .history(entries.map { entry in
                AgentHistoryEntry(
                    timestamp: entry.timestamp,
                    originalURL: entry.originalURL,
                    cleanedURL: entry.cleanedURL,
                    outcome: entry.outcome.rawValue,
                    targetBundleID: entry.targetBundleID,
                    ruleLabel: entry.ruleLabel,
                    cleaningSteps: entry.cleaningSteps
                )
            })
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

        guard isAcceptableScheme(url) else { return }

        let globalTrace = URLTransformers.default.runTraced(url)

        // Resolve the cleaning flag: an explicit CLI/junction:// `clean=…`
        // wins (user said so), then any matching rule's `cleanOverride`,
        // then the global setting. Looking up the rule even on the explicit-
        // target path lets `cleanOverride` apply when CLI args don't already
        // pin it.
        let context = RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )
        let match = RulesStore.shared.match(url: globalTrace.final, context: context)
        let trace: URLTransformResult
        if let ruleOverrides = match.rule?.trackerOverrides {
            trace = URLTransformers.pipeline(
                globalOverrides: SettingsStore.shared.settings.trackerOverrides,
                ruleOverrides: ruleOverrides
            ).runTraced(url)
        } else {
            trace = globalTrace
        }
        let shouldClean: Bool
        if let explicit = clean {
            shouldClean = explicit
        } else {
            shouldClean = DomainRule.resolveCleanFlag(
                rule: match.rule,
                globalEnabled: SettingsStore.shared.settings.cleanURLsBeforeOpening
            )
        }
        let finalURL = shouldClean ? trace.final : url

        if let key = targetKey,
           let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) {
            URLOpener.open(finalURL, with: option) { success in
                if success {
                    LastURLStore.shared.recordRouted(finalURL)
                    RoutingHistory.shared.record(
                        originalURL: url,
                        result: trace,
                        outcome: .opened,
                        targetBundleID: option.browser.bundleID,
                        ruleLabel: "agent",
                        openedURL: finalURL,
                        sourceBundleID: context.source?.bundleID,
                        targetStorageKey: option.target.storageKey
                    )
                }
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

        // Scheme allow-list. http/https are routable by default; anything else
        // must be opted in by an existing per-host rule (covered downstream),
        // or it gets handed to the system as a last resort. javascript:/data:/
        // file: are dropped outright.
        guard isAcceptableScheme(url) else {
            return
        }

        let contextAtReceive = RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )

        if let rewritten = AppSchemeRewriter.rewrite(
            url,
            using: SettingsStore.shared.settings.appSchemes
        ) {
            NSWorkspace.shared.open(rewritten)
            LastURLStore.shared.recordRouted(url)
            return
        }

        // Pre-normalize for *detection only*: wrapper params (l.facebook.com/?u=…),
        // AMP suffixes, and tracker query items shouldn't hide a shortener
        // host. We never pass `prenormalized` downstream when the user has
        // cleaning disabled — `resolved` always carries the unmodified URL so
        // `urlToOpen = cleaned ? normalized : resolved` actually honors the
        // toggle. (Shortener expansion is the one exception: there `resolved`
        // is the post-redirect target, which is the new "raw" URL.)
        let prenormalized = URLTransformers.default.run(url)

        if SettingsStore.shared.settings.expandShortenedURLs,
           ShortenerExpander.isShortened(prenormalized) {
            ShortenerExpander.shared.expand(prenormalized) { [weak self] expanded in
                DispatchQueue.main.async {
                    self?.routeAfterExpansion(
                        original: url,
                        resolved: expanded,
                        context: contextAtReceive
                    )
                }
            }
            return
        }

        routeAfterExpansion(original: url, resolved: url, context: contextAtReceive)
    }

    private func isAcceptableScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return URLSafety.routableSchemes.contains(scheme)
    }

    private func routeAfterExpansion(original: URL, resolved: URL, context: RouteContext) {
        // Re-run the pipeline post-expansion: shorteners can resolve to URLs
        // that themselves carry trackers, AMP suffixes, or wrapper params.
        // First pass uses global overrides to get a normalized URL for rule matching.
        let globalSettings = SettingsStore.shared.settings
        let globalTrace = URLTransformers.default.runTraced(resolved)
        let normalized = globalTrace.final

        guard isAcceptableScheme(normalized) else { return }

        if let rewritten = AppSchemeRewriter.rewrite(
            normalized,
            using: globalSettings.appSchemes
        ) {
            NSWorkspace.shared.open(rewritten)
            LastURLStore.shared.recordRouted(normalized)
            RoutingHistory.shared.record(
                originalURL: original,
                result: globalTrace,
                outcome: .opened_appScheme,
                ruleLabel: "app-scheme-rewrite",
                sourceBundleID: context.source?.bundleID,
                targetStorageKey: nil
            )
            return
        }

        let match = RulesStore.shared.match(url: normalized, context: context)

        // If the matched rule carries per-rule tracker overrides, rebuild the
        // pipeline merging global + rule overrides and re-run from the resolved
        // URL so the rule's disabled entries can suppress global stripping.
        let trace: URLTransformResult
        if let ruleOverrides = match.rule?.trackerOverrides {
            trace = URLTransformers.pipeline(
                globalOverrides: globalSettings.trackerOverrides,
                ruleOverrides: ruleOverrides
            ).runTraced(resolved)
        } else {
            trace = globalTrace
        }
        let ruleLabel = match.rule.map { "\($0.kindLabel):\($0.displayValue)" }

        if match.rule?.alsoCopyCleaned == true {
            copyCleaned(trace.final)
        }

        // Honor `cleanURLsBeforeOpening` plus the per-rule override: the rule's
        // `cleanOverride` (if set) wins over the global toggle, so users can
        // pin "never clean for myinternal.example.com" or "always clean even
        // when the global setting is off".
        let globalCleaning = SettingsStore.shared.settings.cleanURLsBeforeOpening
        let cleaned = DomainRule.resolveCleanFlag(rule: match.rule, globalEnabled: globalCleaning)
        let urlToOpen = cleaned ? trace.final : resolved

        // Picker keeps the resolved-but-not-yet-cleaned URL so it can show the
        // "cleaned" diff and let the user copy either form.
        switch match.action {
        case .block:
            showBlockedNotice(trace.final)
            RoutingHistory.shared.record(
                originalURL: original,
                result: trace,
                outcome: .blocked,
                ruleLabel: ruleLabel,
                sourceBundleID: context.source?.bundleID,
                targetStorageKey: nil
            )
            return
        case .appScheme(let scheme):
            // Build the deep link from the URL we'd actually open: when the
            // user (or rule) opted out of cleaning, the native app should
            // receive the original URL — templates that interpolate `{query}`
            // shouldn't smuggle the stripped form past the toggle.
            let deepLink = buildSchemeURL(scheme: scheme, from: urlToOpen)
            if let deepLink {
                NSWorkspace.shared.open(deepLink)
                LastURLStore.shared.recordRouted(urlToOpen)
                RoutingHistory.shared.record(
                    originalURL: original,
                    result: trace,
                    outcome: .opened_appScheme,
                    ruleLabel: ruleLabel,
                    openedURL: urlToOpen,
                    sourceBundleID: context.source?.bundleID,
                    targetStorageKey: nil
                )
            } else {
                showPicker(for: resolved, context: context)
                RoutingHistory.shared.record(
                    originalURL: original,
                    result: trace,
                    outcome: .picker,
                    ruleLabel: ruleLabel,
                    sourceBundleID: context.source?.bundleID,
                    targetStorageKey: nil
                )
            }
            return
        case .open(let target):
            guard let option = resolve(target: target) else {
                showPicker(for: resolved, context: context)
                RoutingHistory.shared.record(
                    originalURL: original, result: trace, outcome: .picker, ruleLabel: ruleLabel,
                    sourceBundleID: context.source?.bundleID, targetStorageKey: nil
                )
                return
            }
            URLOpener.open(urlToOpen, with: option) { success in
                if success {
                    LastURLStore.shared.recordRouted(urlToOpen)
                    UndoNotifier.shared.announce(
                        url: urlToOpen,
                        option: option,
                        alternatives: LaunchOptionDiscovery.options()
                    )
                    RoutingHistory.shared.record(
                        originalURL: original,
                        result: trace,
                        outcome: .opened,
                        targetBundleID: option.browser.bundleID,
                        ruleLabel: ruleLabel,
                        openedURL: urlToOpen,
                        sourceBundleID: context.source?.bundleID,
                        targetStorageKey: option.target.storageKey
                    )
                }
            }
        case .openIncognito(let target):
            guard let option = resolve(target: target) else {
                showPicker(for: resolved, context: context)
                RoutingHistory.shared.record(
                    originalURL: original, result: trace, outcome: .picker, ruleLabel: ruleLabel,
                    sourceBundleID: context.source?.bundleID, targetStorageKey: nil
                )
                return
            }
            guard supportsPrivate(option) else {
                showPicker(for: resolved, context: context)
                RoutingHistory.shared.record(
                    originalURL: original, result: trace, outcome: .picker, ruleLabel: ruleLabel,
                    sourceBundleID: context.source?.bundleID, targetStorageKey: nil
                )
                return
            }
            URLOpener.open(urlToOpen, with: option, incognito: true) { success in
                if success {
                    LastURLStore.shared.recordRouted(urlToOpen)
                    RoutingHistory.shared.record(
                        originalURL: original,
                        result: trace,
                        outcome: .openedIncognito,
                        targetBundleID: option.browser.bundleID,
                        ruleLabel: ruleLabel,
                        openedURL: urlToOpen,
                        sourceBundleID: context.source?.bundleID,
                        targetStorageKey: option.target.storageKey
                    )
                }
            }
        case .ask:
            showPicker(for: resolved, context: context)
            RoutingHistory.shared.record(
                originalURL: original,
                result: trace,
                outcome: .picker,
                ruleLabel: ruleLabel,
                sourceBundleID: context.source?.bundleID,
                targetStorageKey: nil
            )
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
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
    }

    private func resolve(target: LaunchTarget) -> LaunchOption? {
        LaunchOptionDiscovery.resolve(target: target)
    }

    private func supportsPrivate(_ option: LaunchOption) -> Bool {
        URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
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
        controller.present(url: url, context: ctx, onOpenPreferences: { [weak self] in
            self?.showPreferences()
        })
    }

    private func showPreferences(focus: PreferencesFocusTarget? = nil) {
        let controller = prefs ?? PreferencesWindowController()
        prefs = controller
        controller.show(focus: focus)
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
