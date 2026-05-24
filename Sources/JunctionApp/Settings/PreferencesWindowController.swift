import AppKit
import SwiftUI

extension Notification.Name {
    static let junctionPreferencesFocusSection = Notification.Name("junctionPreferencesFocusSection")
    static let junctionShowOnboarding = Notification.Name("junctionShowOnboarding")
    static let junctionCheckForUpdates = Notification.Name("junctionCheckForUpdates")
}

enum PreferencesFocusTarget: String {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity, trackers
}

final class PreferencesWindowController {
    private static let toolbarID = NSToolbar.Identifier("JunctionPreferencesToolbar")
    private var window: NSWindow?

    func show(focus: PreferencesFocusTarget? = nil) {
        if let window {
            Self.configureTransparentTitlebar(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            postFocusIfNeeded(focus)
            return
        }

        let view = PreferencesView()
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Junction"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.hasShadow = true
        window.setContentSize(NSSize(width: 880, height: 620))
        window.minSize = NSSize(width: 760, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        Self.configureTransparentTitlebar(window)
        Self.clearHostingBackground(host)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        postFocusIfNeeded(focus)
    }

    /// Lets picker chrome show through the traffic-light titlebar (no opaque system strip).
    private static func configureTransparentTitlebar(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        if #available(macOS 13.0, *) {
            if window.toolbar == nil {
                let toolbar = NSToolbar(identifier: toolbarID)
                toolbar.displayMode = .iconOnly
                window.toolbar = toolbar
            }
            window.toolbarStyle = .unified
        }
    }

    private static func clearHostingBackground(_ host: NSHostingController<some View>) {
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func postFocusIfNeeded(_ focus: PreferencesFocusTarget?) {
        guard let focus else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .junctionPreferencesFocusSection,
                object: nil,
                userInfo: ["section": focus.rawValue]
            )
        }
    }
}

// MARK: - Sections

enum PrefsSection: String, CaseIterable, Identifiable {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity, trackers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .rewrites: return "Redirects"
        case .targets: return "Browsers"
        case .rules: return "Rules"
        case .appSchemes: return "Apps"
        case .hotkeys: return "Shortcuts"
        case .activity: return "History"
        case .trackers: return "Tracking"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .rewrites: return "arrow.left.arrow.right"
        case .targets: return "globe"
        case .rules: return "list.bullet"
        case .appSchemes: return "app"
        case .hotkeys: return "keyboard"
        case .activity: return "clock"
        case .trackers: return "shield"
        }
    }
}

// MARK: - Root view

struct PreferencesView: View {
    @ObservedObject private var settings = SettingsStore.shared

    @State private var options: [LaunchOption] = []
    @State private var rulesFile: RulesFile = RulesStore.shared.rules
    @State private var shadowedRuleIDs: Set<UUID> = RuleConflictDetector.shadowed(rules: RulesStore.shared.rules.rules)
    @State private var selection: PrefsSection = .general
    @State private var showingAddRuleSheet = false
    @State private var newTrackerEntry = ""
    @State private var expandedTargetGroupIDs: Set<String> = []

    private var accent: Color { settings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { settings.settings.chromeTheme }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            PrefsSidebar(selection: $selection, showsBrand: true)

            PrefsVerticalRule()

            VStack(alignment: .leading, spacing: 0) {
                PrefsPageHeader(title: selection.title) {
                    headerAction
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)

                PrefsHairline()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionContent
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            JunctionChromeBackground(theme: theme, accent: accent)
                .ignoresSafeArea()
        }
        .tint(accent)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .junctionRulesChanged)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .junctionPreferencesFocusSection)) { note in
            guard let raw = note.userInfo?["section"] as? String,
                  let target = PrefsSection(rawValue: raw) else { return }
            selection = target
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(options: options)
        }
    }

    @ViewBuilder
    private var headerAction: some View {
        switch selection {
        case .rewrites:
            PrefsButton(title: "Add", symbol: "plus") {
                settings.settings.redirects.append(
                    DomainRedirect(fromHost: "twitter.com", toHost: "x.com", enabled: true, label: nil)
                )
            }
        case .rules:
            PrefsButton(title: "Add rule", symbol: "plus") { showingAddRuleSheet = true }
        case .targets:
            Text("\(visibleCount) shown")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selection {
        case .general: generalPanel
        case .rewrites: rewritesPanel
        case .targets: targetsPanel
        case .rules: rulesPanel
        case .appSchemes: appSchemesPanel
        case .hotkeys: hotkeysPanel
        case .activity: ActivityTab()
        case .trackers: trackersPanel
        }
    }

    // MARK: - General

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrefsBlock(title: "Appearance") {
                PrefsRow(title: "Background") {
                    Picker("", selection: $settings.settings.chromeTheme) {
                        ForEach(ChromeTheme.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }
                PrefsHairline()
                PrefsRow(title: "Accent") {
                    HStack(spacing: 8) {
                        ForEach(AccentPreset.allCases) { preset in
                            PrefsAccentSwatch(
                                preset: preset,
                                isSelected: settings.settings.accentPreset == preset
                            ) {
                                settings.settings.accentPreset = preset
                            }
                        }
                    }
                }
            }

            PrefsBlock(title: "Links") {
                PrefsToggleRow(title: "Remove tracking from URLs", isOn: $settings.settings.cleanURLsBeforeOpening)
                PrefsHairline()
                PrefsToggleRow(title: "Expand shortened links", isOn: $settings.settings.expandShortenedURLs)
                if FeatureFlags.clipboardLinkHUD {
                    PrefsHairline()
                    PrefsToggleRow(
                        title: "Watch clipboard for links",
                        isOn: $settings.settings.clipboardWatcherEnabled
                    )
                }
            }

            AboutAndUpdatesBlock()
        }
    }

    // MARK: - Redirects

    private var rewritesPanel: some View {
        PrefsBlock {
            if settings.settings.redirects.isEmpty {
                PrefsEmptyState(
                    title: "No redirects",
                    message: "Send one site to another, like twitter.com → x.com.",
                    actionTitle: "Add redirect"
                ) {
                    settings.settings.redirects.append(
                        DomainRedirect(fromHost: "twitter.com", toHost: "x.com", enabled: true, label: nil)
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array($settings.settings.redirects.enumerated()), id: \.element.id) { idx, $redirect in
                        rewriteRow(redirect: $redirect)
                        if idx < settings.settings.redirects.count - 1 { PrefsHairline() }
                    }
                }
            }
        }
    }

    private func rewriteRow(redirect: Binding<DomainRedirect>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("", isOn: redirect.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)

                TextField("from.com", text: redirect.fromHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PrefsFieldBackground())

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("to.com", text: redirect.toHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PrefsFieldBackground())

                PrefsIconButton(symbol: "trash", help: "Remove") {
                    if let i = settings.settings.redirects.firstIndex(where: { $0.id == redirect.wrappedValue.id }) {
                        settings.settings.redirects.remove(at: i)
                    }
                }
            }

            TextField("Path template (optional)", text: Binding(
                get: { redirect.wrappedValue.pathTemplate ?? "" },
                set: { redirect.wrappedValue.pathTemplate = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.leading, 38)
        }
        .padding(.vertical, 10)
        .opacity(redirect.wrappedValue.enabled ? 1 : 0.5)
    }

    // MARK: - Browsers

    private var targetsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                PrefsButton(title: "Show all", symbol: "eye") { setAllHidden(false) }
                    .disabled(visibleCount == options.count)
                PrefsButton(title: "Hide all", symbol: "eye.slash") { setAllHidden(true) }
                    .disabled(visibleCount == 0)
                PrefsButton(title: "Reset order", symbol: "arrow.counterclockwise") { resetOrder() }
                    .disabled(settings.settings.targetOrder.isEmpty)
                Spacer()
            }

            PrefsBlock(title: "Shown in picker") {
                browserList(rows: groupedVisibleRows, onMove: moveVisibleGrouped)
            }

            if !hiddenTargets.isEmpty {
                PrefsBlock(title: "Hidden") {
                    browserList(rows: groupedHiddenRows, onMove: moveHiddenGrouped)
                }
            }
        }
    }

    private func browserList(rows: [TargetGroupRow], onMove: @escaping (IndexSet, Int) -> Void) -> some View {
        List {
            ForEach(rows, id: \.rowID) { row in
                targetGroupRow(row)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .overlay(alignment: .bottom) { PrefsHairline() }
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .frame(minHeight: min(CGFloat(rows.count) * 52 + 8, 360))
    }

    // MARK: - Rules

    private var rulesPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrefsBlock {
                if rulesFile.rules.isEmpty {
                    PrefsEmptyState(
                        title: "No rules yet",
                        message: "Open specific sites in the browser you want.",
                        actionTitle: "Add rule"
                    ) { showingAddRuleSheet = true }
                } else {
                    List {
                        ForEach(rulesFile.rules) { rule in
                            ruleRow(rule)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .overlay(alignment: .bottom) { PrefsHairline() }
                        }
                        .onMove { RulesStore.shared.moveRule(from: $0, to: $1) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .frame(minHeight: min(CGFloat(rulesFile.rules.count) * 56 + 8, 420))
                }
            }

            PrefsBlock(title: "When no rule matches") {
                PrefsRow(title: fallbackLabel) {
                    Menu {
                        Button("Ask me") { RulesStore.shared.setFallback(.ask) }
                        Divider()
                        ForEach(options) { option in
                            Button(option.displayName) {
                                RulesStore.shared.setFallback(.open(option.target))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Change")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                }
            }
        }
    }

    private var fallbackLabel: String {
        switch rulesFile.fallback {
        case .ask: return "Ask me"
        case .block: return "Block"
        case .appScheme(let s): return "Open in \(s)"
        case .openIncognito(let t):
            return "Private · " + (options.first { $0.target == t }?.displayName ?? "browser")
        case .open(let t):
            return options.first { $0.target == t }?.displayName ?? "Browser"
        }
    }

    private func ruleRow(_ rule: DomainRule) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { enabled in
                    RulesStore.shared.updateRule(id: rule.id) { $0.enabled = enabled }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.prefsTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let subtitle = rule.prefsSubtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(rule.rulesRowDisplayValue)

            ruleDestination(rule.action)

            if shadowedRuleIDs.contains(rule.id) {
                Text("Overridden")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
            }

            cleanMenu(for: rule)
            PrefsIconButton(symbol: "trash", help: "Remove") {
                RulesStore.shared.remove(ruleID: rule.id)
            }
        }
        .padding(.vertical, 13)
        .opacity(rule.enabled ? 1 : 0.55)
    }

    private func ruleDestination(_ action: RuleAction) -> some View {
        HStack(spacing: 5) {
            switch action {
            case .ask:
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                Text("Ask")
            case .block:
                Image(systemName: "nosign").foregroundStyle(.red)
                Text("Block")
            case .appScheme(let scheme):
                Image(systemName: "app").foregroundStyle(.secondary)
                Text(scheme)
            case .openIncognito(let target):
                Image(systemName: "eyeglasses").foregroundStyle(.secondary)
                Text(options.first { $0.target == target }?.displayName ?? "Private")
            case .open(let target):
                if let opt = options.first(where: { $0.target == target }) {
                    Image(nsImage: opt.icon).resizable().frame(width: 14, height: 14)
                    Text(opt.displayName).lineLimit(1)
                } else {
                    Text("Browser")
                }
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func cleanMenu(for rule: DomainRule) -> some View {
        let current = rule.cleanOverride
        return Menu {
            Button { updateClean(rule.id, nil) } label: {
                Label("Default", systemImage: current == nil ? "checkmark" : "")
            }
            Button { updateClean(rule.id, true) } label: {
                Label("Always clean", systemImage: current == true ? "checkmark" : "")
            }
            Button { updateClean(rule.id, false) } label: {
                Label("Never clean", systemImage: current == false ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(current == true ? Color.accentColor : .secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("URL cleaning for this rule")
    }

    private func updateClean(_ id: UUID, _ value: Bool?) {
        RulesStore.shared.updateRule(id: id) { $0.cleanOverride = value }
    }

    // MARK: - Apps

    private var appSchemesPanel: some View {
        PrefsBlock {
            VStack(spacing: 0) {
                ForEach(Array(settings.settings.appSchemes.enumerated()), id: \.element.id) { idx, rewrite in
                    appSchemeRow(rewrite)
                    if idx < settings.settings.appSchemes.count - 1 { PrefsHairline() }
                }
            }
        }
    }

    private func appSchemeRow(_ rewrite: AppSchemeRewrite) -> some View {
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rewrite.bundleID) != nil
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rewrite.name)
                        .font(.system(size: 13, weight: .medium))
                    if !installed {
                        Text("Not installed")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(rewrite.rules.map(\.host).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rewrite.enabled },
                set: { settings.setAppSchemeEnabled(id: rewrite.id, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(!installed)
        }
        .padding(.vertical, 11)
        .opacity(installed ? 1 : 0.55)
    }

    // MARK: - Shortcuts

    private var hotkeysPanel: some View {
        PrefsBlock {
            hotkeyRow("Open clipboard link", binding: hotkeyBinding(\.summonPicker))
            PrefsHairline()
            hotkeyRow("Re-open last link", binding: hotkeyBinding(\.rerouteLast))
            PrefsHairline()
            hotkeyRow("Paste and open", binding: hotkeyBinding(\.pasteAndOpen))
        }
    }

    private func hotkeyBinding(_ keyPath: WritableKeyPath<HotkeySettings, HotkeyBinding>) -> Binding<HotkeyBinding> {
        Binding(
            get: { settings.settings.hotkeys[keyPath: keyPath] },
            set: { settings.setHotkey($0, for: keyPath) }
        )
    }

    private func hotkeyRow(_ title: String, binding: Binding<HotkeyBinding>) -> some View {
        PrefsRow(title: title) {
            HotkeyRecorderView(binding: binding)
                .frame(width: 150, height: 26)
        }
    }

    // MARK: - Tracking

    private var trackersPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrefsBlock(title: "Custom") {
                HStack(spacing: 10) {
                    TextField("Parameter name", text: $newTrackerEntry)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { addCustomTracker() }
                    PrefsButton(title: "Add", symbol: "plus", action: addCustomTracker)
                        .disabled(newTrackerEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 4)

                let additions = settings.settings.trackerOverrides.additions
                if !additions.isEmpty {
                    PrefsHairline()
                    ForEach(additions, id: \.self) { entry in
                        HStack {
                            Text(entry).font(.system(size: 13, design: .monospaced))
                            Spacer()
                            PrefsIconButton(symbol: "trash", help: "Remove") {
                                settings.settings.trackerOverrides.additions.removeAll { $0 == entry }
                            }
                        }
                        .padding(.vertical, 8)
                        if entry != additions.last { PrefsHairline() }
                    }
                }
            }

            PrefsBlock(title: "Built-in prefixes") {
                trackerList(TrackerStripper.defaultPrefixes)
            }

            PrefsBlock(title: "Built-in parameters") {
                trackerList(TrackerStripper.defaultExactParams.sorted())
            }
        }
    }

    private func trackerList(_ entries: [String]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                trackerRow(entry)
                if idx < entries.count - 1 { PrefsHairline() }
            }
        }
    }

    private func trackerRow(_ entry: String) -> some View {
        let disabled = settings.settings.trackerOverrides.disabled.contains(entry)
        return HStack {
            Text(entry)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(disabled ? .secondary : .primary)
                .strikethrough(disabled)
            Spacer()
            Toggle("", isOn: Binding(
                get: { !disabled },
                set: { on in
                    if on {
                        settings.settings.trackerOverrides.disabled.removeAll { $0 == entry }
                    } else if !settings.settings.trackerOverrides.disabled.contains(entry) {
                        settings.settings.trackerOverrides.disabled.append(entry)
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
        }
        .padding(.vertical, 8)
    }

    private func addCustomTracker() {
        let entry = newTrackerEntry.trimmingCharacters(in: .whitespaces)
        guard !entry.isEmpty else { return }
        guard !settings.settings.trackerOverrides.additions.contains(entry) else {
            newTrackerEntry = ""
            return
        }
        settings.settings.trackerOverrides.additions.append(entry)
        newTrackerEntry = ""
    }

    // MARK: - Target helpers

    private struct TargetGroupRow: Identifiable {
        enum Kind {
            case single(LaunchOption)
            case groupHeader(browser: Browser, count: Int, groupID: String)
            case groupChild(LaunchOption, groupID: String)
        }
        let kind: Kind
        var id: String { rowID }
        var rowID: String {
            switch kind {
            case .single(let o): return o.id
            case .groupHeader(_, _, let g): return g
            case .groupChild(let o, _): return "child:\(o.id)"
            }
        }
        var underlyingOption: LaunchOption? {
            switch kind {
            case .single(let o): return o
            case .groupHeader: return nil
            case .groupChild(let o, _): return o
            }
        }
        var groupBundleIDForMove: String? {
            if case .groupHeader(let b, _, _) = kind { return b.bundleID }
            return nil
        }
    }

    private func buildGroupedRows(from flat: [LaunchOption]) -> [TargetGroupRow] {
        var rows: [TargetGroupRow] = []
        for item in LaunchOptionGrouping.group(options: flat) {
            switch item {
            case .single(let opt):
                rows.append(TargetGroupRow(kind: .single(opt)))
            case .group(let browser, let opts):
                let gid = "group:\(browser.bundleID)"
                rows.append(TargetGroupRow(kind: .groupHeader(browser: browser, count: opts.count, groupID: gid)))
                if expandedTargetGroupIDs.contains(gid) {
                    for opt in opts {
                        rows.append(TargetGroupRow(kind: .groupChild(opt, groupID: gid)))
                    }
                }
            }
        }
        return rows
    }

    private var groupedVisibleRows: [TargetGroupRow] { buildGroupedRows(from: visibleTargets) }
    private var groupedHiddenRows: [TargetGroupRow] { buildGroupedRows(from: hiddenTargets) }
    private var visibleTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { !hidden.contains($0.target.storageKey) }
    }
    private var hiddenTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { hidden.contains($0.target.storageKey) }
    }
    private var visibleCount: Int { visibleTargets.count }

    @ViewBuilder
    private func targetGroupRow(_ row: TargetGroupRow) -> some View {
        switch row.kind {
        case .single(let opt): targetRow(opt)
        case .groupHeader(let browser, let count, let gid): groupHeader(browser, count: count, gid: gid)
        case .groupChild(let opt, _): targetRow(opt).padding(.leading, 20)
        }
    }

    private func groupHeader(_ browser: Browser, count: Int, gid: String) -> some View {
        let expanded = expandedTargetGroupIDs.contains(gid)
        return HStack(spacing: 12) {
            grip
            Image(nsImage: browser.icon).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(browser.name).font(.system(size: 13, weight: .medium))
                Text("\(count) profiles").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if expanded { expandedTargetGroupIDs.remove(gid) } else { expandedTargetGroupIDs.insert(gid) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
    }

    private func targetRow(_ option: LaunchOption) -> some View {
        let key = option.target.storageKey
        let hidden = settings.settings.hiddenTargetKeys.contains(key)
        let pinned = settings.settings.pinnedTargetKey == key
        return HStack(spacing: 12) {
            grip
            Image(nsImage: option.icon).resizable().frame(width: 22, height: 22).opacity(hidden ? 0.4 : 1)
            Text(option.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hidden ? .secondary : .primary)
            Spacer()
            Button { settings.setPinnedTargetKey(pinned ? nil : key) } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(pinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(pinned ? "Unpin" : "Pin to top")
            Toggle("", isOn: Binding(
                get: { !hidden },
                set: { settings.setHidden(!$0, for: key) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
        }
        .padding(.vertical, 11)
    }

    private var grip: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 12)
    }

    private func moveVisibleGrouped(from source: IndexSet, to destination: Int) {
        moveGrouped(source: source, destination: destination, rows: groupedVisibleRows, flat: visibleTargets) { visible in
            options = visible + hiddenTargets
            settings.setTargetOrder(options.map(\.target.storageKey))
        }
    }

    private func moveHiddenGrouped(from source: IndexSet, to destination: Int) {
        moveGrouped(source: source, destination: destination, rows: groupedHiddenRows, flat: hiddenTargets) { hidden in
            options = visibleTargets + hidden
            settings.setTargetOrder(options.map(\.target.storageKey))
        }
    }

    private func moveGrouped(
        source: IndexSet,
        destination: Int,
        rows: [TargetGroupRow],
        flat: [LaunchOption],
        apply: (inout [LaunchOption]) -> Void
    ) {
        var list = flat
        let indices = LaunchOptionGrouping.flatMoveSourceIndices(
            sourceRowIndices: source,
            groupBundleIDAtRow: { rows[$0].groupBundleIDForMove },
            optionAtRow: { rows[$0].underlyingOption },
            in: list
        )
        guard !indices.isEmpty else { return }
        let dest = LaunchOptionGrouping.resolveDestinationIndex(
            destination: destination,
            rowUnderlyingOptions: rows.map(\.underlyingOption),
            flat: list,
            fallback: moveFallback(destination, rows: rows, flat: list)
        )
        list.move(fromOffsets: indices, toOffset: dest)
        apply(&list)
    }

    private func moveFallback(_ dest: Int, rows: [TargetGroupRow], flat: [LaunchOption]) -> LaunchOption {
        guard dest < rows.count else { return flat.last ?? flat.first! }
        if let o = rows[dest].underlyingOption { return o }
        if case .groupHeader(let b, _, _) = rows[dest].kind,
           let first = flat.first(where: { $0.browser.bundleID == b.bundleID }) { return first }
        return flat.first!
    }

    private func resetOrder() {
        settings.setTargetOrder([])
        options = LaunchOptionDiscovery.options()
    }

    private func setAllHidden(_ hidden: Bool) {
        for o in options { settings.setHidden(hidden, for: o.target.storageKey) }
    }

    private func reload() {
        options = LaunchOptionDiscovery.options()
        rulesFile = RulesStore.shared.rules
        shadowedRuleIDs = RuleConflictDetector.shadowed(rules: rulesFile.rules)
        expandedTargetGroupIDs = LaunchOptionGrouping.defaultExpandedGroupIDs(
            grouped: LaunchOptionGrouping.group(options: options),
            pinnedTargetKey: settings.settings.pinnedTargetKey
        )
    }
}
