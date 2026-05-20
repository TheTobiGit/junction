import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when an external trigger (Recent submenu, etc.) wants the
    /// Preferences window to switch to a specific tab on next presentation.
    static let junctionPreferencesFocusSection = Notification.Name("junctionPreferencesFocusSection")
}

/// Identifier matched by ``PreferencesView`` to set its initial selection.
enum PreferencesFocusTarget: String {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity, trackers
}

final class PreferencesWindowController {
    private var window: NSWindow?

    func show(focus: PreferencesFocusTarget? = nil) {
        if let window {
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 1040, height: 720))
        window.minSize = NSSize(width: 920, height: 640)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        postFocusIfNeeded(focus)
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

enum PrefsSection: String, CaseIterable, Identifiable {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity, trackers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .rewrites:   return "Rewrites"
        case .targets:    return "Browsers"
        case .rules:      return "Rules"
        case .appSchemes: return "Native apps"
        case .hotkeys:    return "Hotkeys"
        case .activity:   return "Activity"
        case .trackers:   return "Trackers"
        }
    }

    /// One-line tagline shown only at the top of the body, never in the rail.
    var tagline: String {
        switch self {
        case .general:    return "Behavior, look, and link cleaning."
        case .rewrites:   return "Replace a URL's host before routing."
        case .targets:    return "Browsers and profiles Junction can open."
        case .rules:      return "First match wins. Drag to reorder."
        case .appSchemes: return "Open matching links in a native app."
        case .hotkeys:    return "Global shortcuts that work everywhere."
        case .activity:   return "Recently routed links, stored locally."
        case .trackers:   return "Customize which tracking params are stripped."
        }
    }

    /// Sole splash of color per section — used for the rail dot and the
    /// accent on the body title. No icon tiles, no badges.
    var tint: Color {
        switch self {
        case .general:    return .accentColor
        case .rewrites:   return .orange
        case .targets:    return .teal
        case .rules:      return .purple
        case .appSchemes: return .pink
        case .hotkeys:    return .blue
        case .activity:   return .green
        case .trackers:   return .red
        }
    }
}

// MARK: - Root view

struct PreferencesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var options: [LaunchOption] = []
    @State private var rulesFile: RulesFile = RulesStore.shared.rules
    @State private var shadowedRuleIDs: Set<UUID> = RuleConflictDetector.shadowed(rules: RulesStore.shared.rules.rules)
    @State private var selection: PrefsSection = .general
    @State private var showingAddRuleSheet: Bool = false
    @State private var hoveredRail: PrefsSection? = nil
    @State private var newTrackerEntry: String = ""
    @State private var expandedTargetGroupIDs: Set<String> = []
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            verticalHairline

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(canvasBackground)
        .tint(settings.settings.accentPreset.swiftUIColor)
        .frame(minWidth: 920, minHeight: 640)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .junctionRulesChanged)) { _ in
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .junctionPreferencesFocusSection)) { note in
            guard let raw = note.userInfo?["section"] as? String,
                  let target = PrefsSection(rawValue: raw)
            else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                selection = target
            }
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(options: options)
        }
    }

    // MARK: - Canvas

    /// A single flat backdrop. No radial spotlights, no per-section tint —
    /// just near-black slate (dark) or a soft warm white (light).
    private var canvasBackground: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
            (colorScheme == .dark
             ? Color(red: 0.075, green: 0.075, blue: 0.085)
             : Color(red: 0.985, green: 0.980, blue: 0.975))
                .opacity(0.96)
        }
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.07))
            .frame(width: 0.5)
    }

    private func hairline() -> some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.06))
            .frame(height: 0.5)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 26)

            VStack(spacing: 1) {
                ForEach(PrefsSection.allCases) { section in
                    sidebarRow(section)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            sidebarFooter
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            settings.settings.accentPreset.swiftUIColor,
                            settings.settings.accentPreset.swiftUIColor.opacity(0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 10, height: 10)
            Text("Junction")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func sidebarRow(_ section: PrefsSection) -> some View {
        let isSelected = selection == section
        let isHovered = hoveredRail == section && !isSelected
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { selection = section }
        } label: {
            HStack(spacing: 11) {
                Circle()
                    .fill(section.tint)
                    .frame(width: 7, height: 7)
                    .opacity(isSelected ? 1.0 : 0.55)

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(
                        isSelected
                        ? Color.primary
                        : Color.primary.opacity(isHovered ? 0.85 : 0.60)
                    )
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
                        : (isHovered ? Color.primary.opacity(0.03) : .clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredRail = section }
            else if hoveredRail == section { hoveredRail = nil }
        }
        .accessibilityLabel(Text(section.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green.opacity(0.7))
                .frame(width: 5, height: 5)
            Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.65))
            Spacer(minLength: 0)
        }
    }

    // MARK: - Content scroll area

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                contentHeader
                    .padding(.bottom, 36)

                tabBody
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 56)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(selection.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.interpolate)
                Spacer(minLength: 16)
                headerAction
            }
            Text(selection.tagline)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
        }
    }

    @ViewBuilder
    private var headerAction: some View {
        switch selection {
        case .rewrites:
            ghostButton("Add rewrite", symbol: "plus") {
                withAnimation(.easeOut(duration: 0.18)) {
                    settings.settings.redirects.append(
                        DomainRedirect(
                            fromHost: "example.com",
                            toHost: "example.net",
                            enabled: true,
                            label: nil
                        )
                    )
                }
            }
        case .rules:
            ghostButton("Add rule", symbol: "plus") { showingAddRuleSheet = true }
        case .targets:
            Text("\(visibleCount) of \(options.count) shown")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch selection {
        case .general:    generalTab
        case .rewrites:   rewritesTab
        case .targets:    targetsTab
        case .rules:      rulesTab
        case .appSchemes: appSchemesTab
        case .hotkeys:    hotkeysTab
        case .activity:   activityTab
        case .trackers:   trackersTab
        }
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 44) {
            section("Appearance") {
                SettingRow(title: "Surface", subtitle: "Glass uses translucent panels; Solid is opaque.") {
                    Picker("", selection: $settings.settings.chromeTheme) {
                        ForEach(ChromeTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                }
                hairline()
                SettingRow(title: "Accent", subtitle: settings.settings.accentPreset.title) {
                    HStack(spacing: 8) {
                        ForEach(AccentPreset.allCases) { preset in
                            accentSwatch(preset)
                        }
                    }
                }
            }

            section("Routing") {
                SettingRow(title: "Clean URLs", subtitle: "Strip utm_*, fbclid, gclid and friends.") {
                    Toggle("", isOn: $settings.settings.cleanURLsBeforeOpening).labelsHidden().toggleStyle(.switch)
                }
                hairline()
                SettingRow(title: "Expand shortened links", subtitle: "Resolve t.co, bit.ly, lnkd.in first.") {
                    Toggle("", isOn: $settings.settings.expandShortenedURLs).labelsHidden().toggleStyle(.switch)
                }
                hairline()
                SettingRow(title: "Watch clipboard", subtitle: "Show a HUD when you copy a link.") {
                    Toggle("", isOn: $settings.settings.clipboardWatcherEnabled).labelsHidden().toggleStyle(.switch)
                }
                hairline()
                SettingRow(title: "Record activity", subtitle: "Keep a local log of recent links.") {
                    Toggle("", isOn: $settings.settings.historyEnabled).labelsHidden().toggleStyle(.switch)
                }
            }

            section("Diagnostics") {
                URLInspectorCard()
            }
        }
    }

    private func accentSwatch(_ preset: AccentPreset) -> some View {
        let isSelected = settings.settings.accentPreset == preset
        return Button {
            settings.settings.accentPreset = preset
        } label: {
            ZStack {
                if preset == .system {
                    Circle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 18, height: 18)
                    Image(systemName: "apple.logo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Circle()
                        .fill(preset.swiftUIColor)
                        .frame(width: 18, height: 18)
                }
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(preset.title)
        .accessibilityLabel(Text(preset.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Rewrites

    private var rewritesTab: some View {
        Group {
            if settings.settings.redirects.isEmpty {
                emptyStateText(
                    "No rewrites yet.",
                    detail: "Use Add rewrite to send a host through a different domain."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array($settings.settings.redirects.enumerated()), id: \.element.id) { idx, $redirect in
                        rewriteRow(redirect: $redirect)
                        if idx < settings.settings.redirects.count - 1 { hairline() }
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

                plainField(text: redirect.fromHost, placeholder: "from-host")

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                plainField(text: redirect.toHost, placeholder: "to-host")

                deleteIconButton(help: "Remove rewrite") {
                    withAnimation(.easeOut(duration: 0.18)) {
                        if let idx = settings.settings.redirects.firstIndex(where: { $0.id == redirect.wrappedValue.id }) {
                            settings.settings.redirects.remove(at: idx)
                        }
                    }
                }
            }

            TextField(
                "/article{path}   (optional path template)",
                text: Binding(
                    get: { redirect.wrappedValue.pathTemplate ?? "" },
                    set: { redirect.wrappedValue.pathTemplate = $0.isEmpty ? nil : $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.leading, 38)
        }
        .padding(.vertical, 14)
        .opacity(redirect.wrappedValue.enabled ? 1.0 : 0.55)
    }

    private func plainField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Targets (browsers)

    private var targetsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ghostButton("Show all", symbol: "eye") { setAllHidden(false) }
                    .disabled(visibleCount == options.count)
                ghostButton("Hide all", symbol: "eye.slash") { setAllHidden(true) }
                    .disabled(visibleCount == 0)
                ghostButton("Reset order", symbol: "arrow.uturn.backward") { resetOrder() }
                    .disabled(settings.settings.targetOrder.isEmpty)
                Spacer()
            }

            List {
                Section {
                    ForEach(groupedVisibleRows, id: \.rowID) { row in
                        targetGroupRow(row)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .overlay(alignment: .bottom) { hairline() }
                    }
                    .onMove(perform: moveVisibleGrouped)
                } header: {
                    subSectionLabel("Visible", count: visibleTargets.count)
                }

                if !hiddenTargets.isEmpty {
                    Section {
                        ForEach(groupedHiddenRows, id: \.rowID) { row in
                            targetGroupRow(row)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .overlay(alignment: .bottom) { hairline() }
                        }
                        .onMove(perform: moveHiddenGrouped)
                    } header: {
                        subSectionLabel("Hidden", count: hiddenTargets.count)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 380)
        }
    }

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
            case .single(let opt): return opt.id
            case .groupHeader(_, _, let gid): return gid
            case .groupChild(let opt, _): return "child:\(opt.id)"
            }
        }
        var underlyingOption: LaunchOption? {
            switch kind {
            case .single(let opt): return opt
            case .groupHeader: return nil
            case .groupChild(let opt, _): return opt
            }
        }
    }

    private func buildGroupedRows(from flat: [LaunchOption]) -> [TargetGroupRow] {
        let grouped = LaunchOptionGrouping.group(options: flat)
        var rows: [TargetGroupRow] = []
        for item in grouped {
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

    @ViewBuilder
    private func targetGroupRow(_ row: TargetGroupRow) -> some View {
        switch row.kind {
        case .single(let opt):
            targetRow(opt)
        case .groupHeader(let browser, let count, let groupID):
            targetGroupHeaderRow(browser: browser, count: count, groupID: groupID)
        case .groupChild(let opt, _):
            targetRow(opt).padding(.leading, 20)
        }
    }

    private func targetGroupHeaderRow(browser: Browser, count: Int, groupID: String) -> some View {
        let isExpanded = expandedTargetGroupIDs.contains(groupID)
        return HStack(spacing: 14) {
            Image(nsImage: browser.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(browser.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(count) profiles")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.7))
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.18)) {
                if isExpanded {
                    expandedTargetGroupIDs.remove(groupID)
                } else {
                    expandedTargetGroupIDs.insert(groupID)
                }
            }
        }
    }

    /// Flat insertion anchor for a grouped row index. Group headers have no
    /// underlying option; use the first target in that browser group so drops
    /// before a collapsed header resolve to the group's position, not the
    /// dragged item's current index.
    private func destinationInsertionOption(
        at destination: Int,
        in rows: [TargetGroupRow],
        flat: [LaunchOption]
    ) -> LaunchOption {
        guard destination < rows.count else {
            return flat.last ?? flat.first!
        }
        if let opt = rows[destination].underlyingOption {
            return opt
        }
        if case .groupHeader(let browser, _, _) = rows[destination].kind,
           let first = flat.first(where: { $0.browser.bundleID == browser.bundleID }) {
            return first
        }
        return flat.first!
    }

    private func moveVisibleGrouped(from source: IndexSet, to destination: Int) {
        let rows = groupedVisibleRows
        let underlyingMoved = source.compactMap { rows[$0].underlyingOption }
        guard !underlyingMoved.isEmpty else { return }
        var visible = visibleTargets
        let sourceIndices = IndexSet(underlyingMoved.compactMap { moved in
            visible.firstIndex(where: { $0.id == moved.id })
        })
        let destIdx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: destination,
            rowUnderlyingOptions: rows.map { $0.underlyingOption },
            flat: visible,
            fallback: destinationInsertionOption(at: destination, in: rows, flat: visible)
        )
        visible.move(fromOffsets: sourceIndices, toOffset: destIdx)
        options = visible + hiddenTargets
        settings.setTargetOrder(options.map { $0.target.storageKey })
    }

    private func moveHiddenGrouped(from source: IndexSet, to destination: Int) {
        let rows = groupedHiddenRows
        let underlyingMoved = source.compactMap { rows[$0].underlyingOption }
        guard !underlyingMoved.isEmpty else { return }
        var hidden = hiddenTargets
        let sourceIndices = IndexSet(underlyingMoved.compactMap { moved in
            hidden.firstIndex(where: { $0.id == moved.id })
        })
        let destIdx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: destination,
            rowUnderlyingOptions: rows.map { $0.underlyingOption },
            flat: hidden,
            fallback: destinationInsertionOption(at: destination, in: rows, flat: hidden)
        )
        hidden.move(fromOffsets: sourceIndices, toOffset: destIdx)
        options = visibleTargets + hidden
        settings.setTargetOrder(options.map { $0.target.storageKey })
    }

    private var visibleTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { !hidden.contains($0.target.storageKey) }
    }

    private var hiddenTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { hidden.contains($0.target.storageKey) }
    }

    private var visibleCount: Int { visibleTargets.count }

    private func targetRow(_ option: LaunchOption) -> some View {
        let key = option.target.storageKey
        let isHidden = settings.settings.hiddenTargetKeys.contains(key)
        let isPinned = settings.settings.pinnedTargetKey == key
        return HStack(spacing: 14) {
            Image(nsImage: option.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .opacity(isHidden ? 0.40 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHidden ? .secondary : .primary)
                    .lineLimit(1)
                Text(option.target.storageKey)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    settings.setPinnedTargetKey(isPinned ? nil : key)
                })
                .help(isPinned ? "Unpin from first slot" : "Pin to first slot")

            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { settings.setHidden(!$0, for: key) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
        }
        .padding(.vertical, 12)
    }

    private func moveVisible(from source: IndexSet, to destination: Int) {
        var visible = visibleTargets
        visible.move(fromOffsets: source, toOffset: destination)
        options = visible + hiddenTargets
        settings.setTargetOrder(options.map { $0.target.storageKey })
    }

    private func moveHidden(from source: IndexSet, to destination: Int) {
        var hidden = hiddenTargets
        hidden.move(fromOffsets: source, toOffset: destination)
        options = visibleTargets + hidden
        settings.setTargetOrder(options.map { $0.target.storageKey })
    }

    private func resetOrder() {
        settings.setTargetOrder([])
        options = LaunchOptionDiscovery.options()
    }

    private func setAllHidden(_ hidden: Bool) {
        for option in options {
            settings.setHidden(hidden, for: option.target.storageKey)
        }
    }

    // MARK: - Rules

    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: 28) {
            if rulesFile.rules.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    RulesEmptyIllustration()
                    emptyStateText(
                        "No rules yet.",
                        detail: "Use the Remember toggle in the picker or Add rule above."
                    )
                }
            } else {
                List {
                    ForEach(rulesFile.rules) { rule in
                        ruleRow(rule)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .overlay(alignment: .bottom) { hairline() }
                    }
                    .onMove { source, destination in
                        RulesStore.shared.moveRule(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 240, maxHeight: 560)
            }

            section("Fallback") {
                fallbackRow
            }
        }
    }

    private func ruleRow(_ rule: DomainRule) -> some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { rule.enabled },
                    set: { newValue in
                        RulesStore.shared.updateRule(id: rule.id) { $0.enabled = newValue }
                    }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            Text(rule.kindLabel.lowercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Text(rule.rulesRowDisplayValue)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(rule.enabled ? .primary : Color.primary.opacity(0.5))
                .strikethrough(!rule.enabled, color: .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(rule.rulesRowDisplayValue)

            actionLabel(rule.action, compact: true)
                .foregroundStyle(.secondary)

            if shadowedRuleIDs.contains(rule.id) {
                Text("shadowed")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                    )
            }

            cleanOverrideMenu(for: rule)

            deleteIconButton(help: "Remove rule") {
                withAnimation(.easeOut(duration: 0.18)) {
                    RulesStore.shared.remove(ruleID: rule.id)
                }
            }
        }
        .padding(.vertical, 12)
        .opacity(rule.enabled ? 1.0 : 0.62)
    }

    private func cleanOverrideMenu(for rule: DomainRule) -> some View {
        let current = rule.cleanOverride
        return Menu {
            Button { updateCleanOverride(ruleID: rule.id, to: nil) } label: {
                Label("Use global setting", systemImage: current == nil ? "checkmark" : "")
            }
            Button { updateCleanOverride(ruleID: rule.id, to: true) } label: {
                Label("Always clean", systemImage: current == true ? "checkmark" : "")
            }
            Button { updateCleanOverride(ruleID: rule.id, to: false) } label: {
                Label("Never clean", systemImage: current == false ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(cleanOverrideTint(current))
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(cleanOverrideHelp(current))
    }

    private func cleanOverrideHelp(_ value: Bool?) -> String {
        switch value {
        case .none:        return "Cleaning: inherit global"
        case .some(true):  return "Cleaning: always"
        case .some(false): return "Cleaning: never"
        }
    }

    private func cleanOverrideTint(_ value: Bool?) -> Color {
        switch value {
        case .none:        return .secondary.opacity(0.7)
        case .some(true):  return .accentColor
        case .some(false): return .orange
        }
    }

    private func updateCleanOverride(ruleID: UUID, to value: Bool?) {
        RulesStore.shared.updateRule(id: ruleID) { rule in
            rule.cleanOverride = value
        }
    }

    /// Inline action representation for a rule. Kept text-only and compact
    /// so the row scans like a sentence: `[toggle] suffix github.com → Chrome`.
    private func actionLabel(_ action: RuleAction, compact: Bool = false) -> some View {
        let bodySize: CGFloat = compact ? 11 : 12
        let iconSide: CGFloat = compact ? 12 : 14
        return HStack(spacing: 5) {
            switch action {
            case .ask:
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
                Text("Ask").font(.system(size: bodySize, weight: .medium))
            case .block:
                Image(systemName: "nosign").foregroundStyle(.red)
                Text("Block").font(.system(size: bodySize, weight: .medium))
            case .appScheme(let scheme):
                Image(systemName: "app.fill").foregroundStyle(.pink)
                Text(scheme).font(.system(size: bodySize, design: .monospaced)).lineLimit(1).truncationMode(.middle)
            case .openIncognito(let target):
                Image(systemName: "eyeglasses").foregroundStyle(.indigo)
                if let opt = options.first(where: { $0.target == target }) {
                    Text("Private · \(opt.displayName)").font(.system(size: bodySize, weight: .medium)).lineLimit(1)
                } else {
                    Text("Private · \(target.storageKey)").font(.system(size: bodySize, design: .monospaced))
                }
            case .open(let target):
                if let opt = options.first(where: { $0.target == target }) {
                    Image(nsImage: opt.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: iconSide, height: iconSide)
                    Text(opt.displayName).font(.system(size: bodySize, weight: .medium)).lineLimit(1).truncationMode(.middle)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(target.storageKey).font(.system(size: bodySize, design: .monospaced))
                }
            }
        }
    }

    private var fallbackRow: some View {
        SettingRow(title: "When no rule matches", subtitle: actionDescription(rulesFile.fallback)) {
            Menu {
                Button("Always ask") { RulesStore.shared.setFallback(.ask) }
                Divider()
                ForEach(options) { option in
                    Button(option.displayName) {
                        RulesStore.shared.setFallback(.open(option.target))
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Change").font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    /// Plain-text description of an action — used in rows where we don't
    /// want the busy icon-and-name treatment.
    private func actionDescription(_ action: RuleAction) -> String {
        switch action {
        case .ask:                  return "Show the picker."
        case .block:                return "Block the link."
        case .appScheme(let s):     return "Open via \(s)://"
        case .openIncognito(let t): return "Private · " + (options.first { $0.target == t }?.displayName ?? t.storageKey)
        case .open(let t):          return options.first { $0.target == t }?.displayName ?? t.storageKey
        }
    }

    // MARK: - Native apps

    private var appSchemesTab: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.settings.appSchemes.enumerated()), id: \.element.id) { idx, rewrite in
                appSchemeRow(rewrite)
                if idx < settings.settings.appSchemes.count - 1 { hairline() }
            }
        }
    }

    private func appSchemeRow(_ rewrite: AppSchemeRewrite) -> some View {
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rewrite.bundleID) != nil
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(rewrite.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(installed ? .primary : .secondary)
                    if !installed {
                        Text("not installed")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
                Text(rewrite.rules.map { $0.host }.joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rewrite.enabled },
                set: { settings.setAppSchemeEnabled(id: rewrite.id, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .disabled(!installed)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        VStack(spacing: 0) {
            hotkeyRow(
                title: "Open clipboard link",
                subtitle: "Show the picker for the URL on your clipboard.",
                binding: Binding(
                    get: { settings.settings.hotkeys.summonPicker },
                    set: { settings.setHotkey($0, for: \.summonPicker) }
                )
            )
            hairline()
            hotkeyRow(
                title: "Reroute last link",
                subtitle: "Show the picker for the most recent URL.",
                binding: Binding(
                    get: { settings.settings.hotkeys.rerouteLast },
                    set: { settings.setHotkey($0, for: \.rerouteLast) }
                )
            )
            hairline()
            hotkeyRow(
                title: "Paste & open",
                subtitle: "Open the clipboard URL with your rules.",
                binding: Binding(
                    get: { settings.settings.hotkeys.pasteAndOpen },
                    set: { settings.setHotkey($0, for: \.pasteAndOpen) }
                )
            )
        }
    }

    private func hotkeyRow(title: String, subtitle: String, binding: Binding<HotkeyBinding>) -> some View {
        SettingRow(title: title, subtitle: subtitle) {
            HotkeyRecorderView(binding: binding)
                .frame(width: 150, height: 26)
        }
    }

    private var activityTab: some View {
        ActivityTab()
    }

    // MARK: - Trackers

    private var trackersTab: some View {
        VStack(alignment: .leading, spacing: 44) {
            section("Custom trackers") {
                HStack(spacing: 10) {
                    TextField("param_name or prefix_", text: $newTrackerEntry)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit { addCustomTracker() }
                    ghostButton("Add", symbol: "plus") { addCustomTracker() }
                        .disabled(newTrackerEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 12)
                .help("Entries ending in _ are treated as prefixes (e.g. mc_ strips mc_eid, mc_cid). All others match exact param names.")

                let additions = settings.settings.trackerOverrides.additions
                if !additions.isEmpty {
                    hairline()
                    ForEach(additions, id: \.self) { entry in
                        HStack(spacing: 8) {
                            Text(entry)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.primary)
                            if entry.hasSuffix("_") {
                                Text("prefix")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .tracking(0.3)
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.secondary.opacity(0.10))
                                    )
                            }
                            Spacer()
                            deleteIconButton(help: "Remove \(entry)") {
                                settings.settings.trackerOverrides.additions.removeAll { $0 == entry }
                            }
                        }
                        .padding(.vertical, 10)
                        if entry != additions.last { hairline() }
                    }
                }
            }

            section("Built-in prefixes") {
                ForEach(Array(TrackerStripper.defaultPrefixes.enumerated()), id: \.offset) { idx, prefix in
                    builtInTrackerRow(entry: prefix, isLast: idx == TrackerStripper.defaultPrefixes.count - 1)
                }
            }

            section("Built-in params") {
                let sorted = TrackerStripper.defaultExactParams.sorted()
                ForEach(Array(sorted.enumerated()), id: \.offset) { idx, param in
                    builtInTrackerRow(entry: param, isLast: idx == sorted.count - 1)
                }
            }
        }
    }

    private func builtInTrackerRow(entry: String, isLast: Bool) -> some View {
        let isDisabled = settings.settings.trackerOverrides.disabled.contains(entry)
        return VStack(spacing: 0) {
            HStack {
                Text(entry)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
                    .strikethrough(isDisabled, color: .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { !isDisabled },
                    set: { enabled in
                        if enabled {
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
            .padding(.vertical, 10)
            if !isLast { hairline() }
        }
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

    // MARK: - Primitives

    /// Top-level grouping inside a tab. Just an uppercase label, then content.
    /// No card, no border — content sits flat on the canvas.
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.bottom, 12)
            VStack(spacing: 0) {
                content()
            }
        }
    }

    /// Sub-heading used inside a List section (Targets/Rules grouping).
    private func subSectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary.opacity(0.7))
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.5))
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func emptyStateText(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
    }

    /// Lightweight bordered button used in the header (Add rewrite, Add rule)
    /// and the Targets tab quick-actions. No filled chrome — just text plus
    /// optional symbol, with a hairline border.
    private func ghostButton(_ title: String, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func deleteIconButton(help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func reload() {
        options = LaunchOptionDiscovery.options()
        rulesFile = RulesStore.shared.rules
        shadowedRuleIDs = RuleConflictDetector.shadowed(rules: rulesFile.rules)
        let grouped = LaunchOptionGrouping.group(options: options)
        expandedTargetGroupIDs = LaunchOptionGrouping.defaultExpandedGroupIDs(
            grouped: grouped,
            pinnedTargetKey: settings.settings.pinnedTargetKey
        )
    }
}

// MARK: - Generic settings row

/// Two-column row used everywhere: title (+ optional subtitle) on the left,
/// trailing control on the right. Zero chrome — separation between rows is
/// handled by `hairline()` painted by the parent.
struct SettingRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 24)

            trailing()
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Add rule sheet
