import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when an external trigger (Recent submenu, etc.) wants the
    /// Preferences window to switch to a specific tab on next presentation.
    static let junctionPreferencesFocusSection = Notification.Name("junctionPreferencesFocusSection")
}

/// Identifier matched by ``PreferencesView`` to set its initial selection.
enum PreferencesFocusTarget: String {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity
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
        window.title = "Junction Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 780, height: 560))
        window.minSize = NSSize(width: 720, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        postFocusIfNeeded(focus)
    }

    /// Posts the focus notification on the next runloop tick. The view's
    /// `.onReceive` subscriber is only attached after `body` runs, so a
    /// synchronous post during ``show(focus:)`` would arrive before there's
    /// anyone listening.
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

private enum PrefsSection: String, CaseIterable, Identifiable {
    case general, rewrites, targets, rules, appSchemes, hotkeys, activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .rewrites:   return "Rewrites"
        case .targets:    return "Targets"
        case .rules:      return "Rules"
        case .appSchemes: return "Native Apps"
        case .hotkeys:    return "Hotkeys"
        case .activity:   return "Activity"
        }
    }

    var subtitle: String {
        switch self {
        case .general:    return "Link handling"
        case .rewrites:   return "Host rewrites"
        case .targets:    return "Browsers and profiles"
        case .rules:      return "Routing rules"
        case .appSchemes: return "Open in desktop app instead"
        case .hotkeys:    return "Global shortcuts"
        case .activity:   return "What Junction did with recent links"
        }
    }

    var symbol: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .rewrites:   return "arrow.triangle.2.circlepath"
        case .targets:    return "globe"
        case .rules:      return "list.bullet.rectangle.fill"
        case .appSchemes: return "app.badge"
        case .hotkeys:    return "command.square.fill"
        case .activity:   return "clock.arrow.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .general:    return .accentColor
        case .rewrites:   return .orange
        case .targets:    return .teal
        case .rules:      return .purple
        case .appSchemes: return .pink
        case .hotkeys:    return .blue
        case .activity:   return .green
        }
    }
}

struct PreferencesView: View {
    @State private var options: [LaunchOption] = []
    @State private var rulesFile: RulesFile = RulesStore.shared.rules
    @State private var selection: PrefsSection = .general
    @State private var showingAddRuleSheet: Bool = false
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 196)

            Divider().opacity(0.18)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        )
        .tint(settings.settings.accentPreset.swiftUIColor)
        .frame(minWidth: 720, minHeight: 500)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .junctionRulesChanged)) { _ in
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .junctionPreferencesFocusSection)) { note in
            guard let raw = note.userInfo?["section"] as? String,
                  let target = PrefsSection(rawValue: raw)
            else { return }
            selection = target
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 5, x: 0, y: 2)
                Text("Junction")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 30)
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(PrefsSection.allCases) { section in
                    sidebarRow(section)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack(spacing: 4) {
                Text("v")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
    }

    private func sidebarRow(_ section: PrefsSection) -> some View {
        let isSelected = selection == section
        return Button(action: { selection = section }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [section.tint.opacity(0.95), section.tint.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.secondary.opacity(0.16), Color.secondary.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: 20)
                    Image(systemName: section.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader

            Divider().opacity(0.12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selection {
                    case .general:    generalTab
                    case .rewrites:   rewritesTab
                    case .targets:    targetsTab
                    case .rules:      rulesTab
                    case .appSchemes: appSchemesTab
                    case .hotkeys:    hotkeysTab
                    case .activity:   activityTab
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selection.title)
                .font(.system(size: 20, weight: .semibold))
            Text(selection.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            appearanceCard
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    toggleRow(
                        title: "Clean URLs",
                        subtitle: "Strip utm_*, fbclid, gclid, and similar trackers before opening.",
                        symbol: "sparkles",
                        tint: .accentColor,
                        isOn: $settings.settings.cleanURLsBeforeOpening
                    )
                    cardDivider
                    toggleRow(
                        title: "Expand shortened links",
                        subtitle: "Resolve t.co, bit.ly, lnkd.in and other shorteners first.",
                        symbol: "arrow.up.right.square",
                        tint: .blue,
                        isOn: $settings.settings.expandShortenedURLs
                    )
                    cardDivider
                    toggleRow(
                        title: "Watch clipboard",
                        subtitle: "Show a HUD when you copy a link so you can clean or route it.",
                        symbol: "doc.on.clipboard",
                        tint: .pink,
                        isOn: $settings.settings.clipboardWatcherEnabled
                    )
                    cardDivider
                    toggleRow(
                        title: "Record activity",
                        subtitle: "Keep a local log of recent links so you can re-route or audit them. Stored on this Mac only.",
                        symbol: "clock.arrow.circlepath",
                        tint: .green,
                        isOn: $settings.settings.historyEnabled
                    )
                }
            }

            URLInspectorCard()
        }
    }

    private var appearanceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.accentColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Glass blurs the desktop behind the picker and clipboard HUD. Solid uses an opaque, textured surface.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Surface")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Picker("Surface style", selection: $settings.settings.chromeTheme) {
                        ForEach(ChromeTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                        spacing: 8
                    ) {
                        ForEach(AccentPreset.allCases) { preset in
                            accentSwatch(preset)
                        }
                    }
                }
            }
            .padding(10)
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
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 30, height: 30)
                    Image(systemName: "apple.logo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                } else {
                    Circle()
                        .fill(preset.swiftUIColor)
                        .frame(width: 30, height: 30)
                }
                Circle()
                    .strokeBorder(
                        Color.primary.opacity(isSelected ? 0.85 : 0.15),
                        lineWidth: isSelected ? 2.25 : 1
                    )
                    .frame(width: isSelected ? 34 : 31, height: isSelected ? 34 : 31)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(preset.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var cardDivider: some View {
        Divider().opacity(0.10).padding(.leading, 56)
    }

    // MARK: - Rewrites

    private var rewritesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlurb(
                "Rewrites replace a URL's host before routing. Disabled rows are skipped.",
                trailing: {
                    Button {
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
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            )

            if settings.settings.redirects.isEmpty {
                emptyState(
                    icon: "arrow.triangle.2.circlepath",
                    title: "No rewrites yet",
                    message: "Add a host rewrite to send links through a different domain."
                )
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array($settings.settings.redirects.enumerated()), id: \.element.id) { idx, $redirect in
                            redirectRow(redirect: $redirect)
                            if idx < settings.settings.redirects.count - 1 {
                                cardDivider
                            }
                        }
                    }
                }
            }
        }
    }

    private func redirectRow(redirect: Binding<DomainRedirect>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Toggle("", isOn: redirect.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)

                TextField("from-host", text: redirect.fromHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))

                TextField("to-host", text: redirect.toHost)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .frame(maxWidth: .infinity)

                if let label = redirect.wrappedValue.label {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.14))
                        )
                        .foregroundColor(.secondary)
                        .fixedSize()
                }

                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        if let idx = settings.settings.redirects.firstIndex(where: { $0.id == redirect.wrappedValue.id }) {
                            settings.settings.redirects.remove(at: idx)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Remove rewrite")
            }

            HStack(spacing: 8) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 22)
                TextField(
                    "path template (optional, e.g. /article{path})",
                    text: Binding(
                        get: { redirect.wrappedValue.pathTemplate ?? "" },
                        set: { redirect.wrappedValue.pathTemplate = $0.isEmpty ? nil : $0 }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                Text("{path} {pathNoSlash} {query} {fragment}")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.leading, 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Targets

    private var targetsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlurb(
                "Detected browsers and profiles. Toggle to hide from the picker, drag to reorder.",
                trailing: {
                    Text("\(visibleCount) of \(options.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.14)))
                }
            )

            HStack(spacing: 6) {
                pillButton("Show all", symbol: "eye") { setAllHidden(false) }
                    .disabled(visibleCount == options.count)
                pillButton("Hide all", symbol: "eye.slash") { setAllHidden(true) }
                    .disabled(visibleCount == 0)
                pillButton("Reset order", symbol: "arrow.uturn.backward") { resetOrder() }
                    .disabled(settings.settings.targetOrder.isEmpty)
                Spacer()
            }

            Card(padding: 0) {
                List {
                    Section {
                        if visibleTargets.isEmpty {
                            Text("No visible targets. Enable at least one below.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(visibleTargets) { option in
                                targetRow(option)
                                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onMove(perform: moveVisible)
                        }
                    } header: {
                        sectionHeader("Visible", count: visibleTargets.count)
                    }

                    if !hiddenTargets.isEmpty {
                        Section {
                            ForEach(hiddenTargets) { option in
                                targetRow(option)
                                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                            .onMove(perform: moveHidden)
                        } header: {
                            sectionHeader("Hidden", count: hiddenTargets.count)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 340)
            }
        }
    }

    private var visibleTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { !hidden.contains($0.target.storageKey) }
    }

    private var hiddenTargets: [LaunchOption] {
        let hidden = Set(settings.settings.hiddenTargetKeys)
        return options.filter { hidden.contains($0.target.storageKey) }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.14)))
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .padding(.horizontal, 4)
    }

    private var visibleCount: Int { visibleTargets.count }

    private func targetRow(_ option: LaunchOption) -> some View {
        let key = option.target.storageKey
        let isHidden = settings.settings.hiddenTargetKeys.contains(key)
        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(width: 14)
                .help("Drag to reorder")

            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { settings.setHidden(!$0, for: key) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: option.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
                    .opacity(isHidden ? 0.4 : 1.0)
                if let hex = option.colorHex, let color = Color(hexString: hex) {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        .offset(x: 2, y: 2)
                        .opacity(isHidden ? 0.4 : 1.0)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isHidden ? .secondary : .primary)
                    .lineLimit(1)
                Text(option.target.storageKey)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHidden {
                Text("Hidden")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.16)))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHidden ? 0.025 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 14) {
            sectionBlurb(
                "Rules are evaluated top to bottom — first match wins. Drag to reorder, toggle to disable without losing the rule.",
                trailing: {
                    pillButton("Add rule", symbol: "plus") {
                        showingAddRuleSheet = true
                    }
                }
            )

            rulesList
            fallbackRow
        }
        .sheet(isPresented: $showingAddRuleSheet) {
            AddRuleSheet(options: options)
        }
    }

    @ViewBuilder
    private var rulesList: some View {
        if rulesFile.rules.isEmpty {
            emptyState(
                icon: "list.bullet.rectangle",
                title: "No rules yet",
                message: "Use the Remember toggle in the picker to save a rule, import a recipe, or edit the rules file directly."
            )
        } else {
            // List (vs. our usual Card+VStack+ForEach) so `.onMove` works on
            // macOS — matches the Targets tab. Background and separators are
            // cleared so the Card's surface shows through unchanged.
            Card(padding: 0) {
                List {
                    ForEach(rulesFile.rules) { rule in
                        ruleRow(rule)
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        RulesStore.shared.moveRule(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 200, maxHeight: 520)
            }
        }
    }

    private func ruleRow(_ rule: DomainRule) -> some View {
        HStack(spacing: 10) {
            // Drag affordance — `.onMove` on the enclosing List provides the
            // actual gesture; this glyph just tells the user it's draggable.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
                .help("Drag to reorder (first match wins)")
                .accessibilityHidden(true)

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
            .help(rule.enabled ? "Disable rule (kept in list, won't match)" : "Enable rule")
            .accessibilityLabel("Enable rule for \(rule.displayValue)")

            // Rest of the row dims when disabled so the rule reads as "kept
            // but inert" instead of looking identical to an active one.
            HStack(spacing: 12) {
                Text(rule.kindLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.14)))
                    .foregroundColor(.secondary)
                    .frame(width: 58, alignment: .center)

                Text(rule.displayValue)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .strikethrough(!rule.enabled, color: .secondary)
                    .help(rule.displayValue)

                Spacer()

                actionLabel(rule.action)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                cleanOverrideMenu(for: rule)

                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        RulesStore.shared.remove(ruleID: rule.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Remove rule")
            }
            .opacity(rule.enabled ? 1.0 : 0.45)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Three-state menu: inherit the global Clean URLs setting, force on, or force off.
    private func cleanOverrideMenu(for rule: DomainRule) -> some View {
        let current = rule.cleanOverride
        return Menu {
            Button {
                updateCleanOverride(ruleID: rule.id, to: nil)
            } label: {
                Label(
                    "Use global setting",
                    systemImage: current == nil ? "checkmark" : ""
                )
            }
            Button {
                updateCleanOverride(ruleID: rule.id, to: true)
            } label: {
                Label(
                    "Always clean",
                    systemImage: current == true ? "checkmark" : ""
                )
            }
            Button {
                updateCleanOverride(ruleID: rule.id, to: false)
            } label: {
                Label(
                    "Never clean",
                    systemImage: current == false ? "checkmark" : ""
                )
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10, weight: .semibold))
                Text(cleanOverrideLabel(current))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(cleanOverrideTint(current))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(cleanOverrideTint(current).opacity(0.15)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Cleaning behavior for this rule")
    }

    private func cleanOverrideLabel(_ value: Bool?) -> String {
        switch value {
        case .none:        return "Inherit"
        case .some(true):  return "Always clean"
        case .some(false): return "Never clean"
        }
    }

    private func cleanOverrideTint(_ value: Bool?) -> Color {
        switch value {
        case .none:        return .secondary
        case .some(true):  return .accentColor
        case .some(false): return .orange
        }
    }

    private func updateCleanOverride(ruleID: UUID, to value: Bool?) {
        RulesStore.shared.updateRule(id: ruleID) { rule in
            rule.cleanOverride = value
        }
    }

    private func actionLabel(_ action: RuleAction) -> some View {
        HStack(spacing: 6) {
            switch action {
            case .ask:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                Text("Always ask")
                    .font(.system(size: 12, weight: .medium))
            case .block:
                Image(systemName: "nosign")
                    .foregroundColor(.red)
                Text("Block")
                    .font(.system(size: 12, weight: .medium))
            case .appScheme(let scheme):
                Image(systemName: "app.badge.fill")
                    .foregroundColor(.pink)
                Text(scheme)
                    .font(.system(size: 12, design: .monospaced))
            case .openIncognito(let target):
                Image(systemName: "eyeglasses")
                    .foregroundColor(.indigo)
                if let opt = options.first(where: { $0.target == target }) {
                    Text("Private · \(opt.displayName)")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Private · \(target.storageKey)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            case .open(let target):
                if let opt = options.first(where: { $0.target == target }) {
                    Image(nsImage: opt.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 14, height: 14)
                    Text(opt.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let hex = opt.colorHex, let color = Color(hexString: hex) {
                        Circle()
                            .fill(color)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(target.storageKey)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
    }

    // MARK: - Native apps

    private var appSchemesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlurb(
                "Matched URLs are handed to the native app when the app is installed. Useful for Slack, Linear, Figma, Notion, Zoom.",
                trailing: { EmptyView() }
            )

            Card {
                VStack(spacing: 0) {
                    ForEach(Array(settings.settings.appSchemes.enumerated()), id: \.element.id) { idx, rewrite in
                        appSchemeRow(rewrite)
                        if idx < settings.settings.appSchemes.count - 1 {
                            cardDivider
                        }
                    }
                }
            }
        }
    }

    private func appSchemeRow(_ rewrite: AppSchemeRewrite) -> some View {
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rewrite.bundleID) != nil
        return HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rewrite.enabled },
                set: { settings.setAppSchemeEnabled(id: rewrite.id, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .disabled(!installed)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rewrite.name)
                        .font(.system(size: 13, weight: .semibold))
                    if !installed {
                        Text("Not installed")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.18)))
                            .foregroundColor(.secondary)
                    }
                }
                Text(rewrite.rules.map { $0.host }.joined(separator: ", "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(rewrite.bundleID)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionBlurb(
                "Global shortcuts work from any app. Click to record, Escape to clear.",
                trailing: { EmptyView() }
            )

            HotkeyRowView(
                title: "Open clipboard link in picker",
                detail: "Trigger the picker for the URL on your clipboard (or the last routed URL if clipboard doesn't have one).",
                binding: Binding(
                    get: { settings.settings.hotkeys.summonPicker },
                    set: { settings.setHotkey($0, for: \.summonPicker) }
                )
            )
            HotkeyRowView(
                title: "Reroute last link",
                detail: "Show the picker for the most recently opened URL, so you can switch browsers.",
                binding: Binding(
                    get: { settings.settings.hotkeys.rerouteLast },
                    set: { settings.setHotkey($0, for: \.rerouteLast) }
                )
            )
            HotkeyRowView(
                title: "Paste & open",
                detail: "Open the clipboard URL using your rules, skipping the picker.",
                binding: Binding(
                    get: { settings.settings.hotkeys.pasteAndOpen },
                    set: { settings.setHotkey($0, for: \.pasteAndOpen) }
                )
            )
        }
    }

    private var activityTab: some View {
        ActivityTab()
    }

    private var fallbackRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.right.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Fallback")
                    .font(.system(size: 12, weight: .semibold))
                Text("Used when no rule matches")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            actionLabel(rulesFile.fallback)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            Menu {
                Button("Always ask") { RulesStore.shared.setFallback(.ask) }
                Divider()
                ForEach(options) { option in
                    Button(option.displayName) {
                        RulesStore.shared.setFallback(.open(option.target))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Change")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Shared UI helpers

    private func sectionBlurb<Trailing: View>(
        _ text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            trailing()
        }
    }

    private func pillButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.secondary.opacity(0.16), Color.secondary.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    private func reload() {
        options = LaunchOptionDiscovery.options()
        rulesFile = RulesStore.shared.rules
    }
}

private struct Card<Content: View>: View {
    var padding: CGFloat = 4
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

// MARK: - Add rule sheet

/// Minimal v1: host kind + value, action of open / incognito / ask / block /
/// app-scheme. Advanced fields (`path`, `queryContains`, `schemes`, `when`,
/// `alsoCopyCleaned`) land in a follow-up — model and matcher already
/// support them, this sheet just doesn't surface them yet so the flow stays
/// fast for the common case.
private struct AddRuleSheet: View {
    let options: [LaunchOption]

    @Environment(\.dismiss) private var dismiss

    @State private var hostKind: HostKind = .suffix
    @State private var hostValue: String = ""
    @State private var actionKind: ActionKind = .open
    @State private var selectedTarget: LaunchTarget? = nil
    @State private var schemeValue: String = ""

    enum HostKind: String, CaseIterable, Identifiable {
        case equals, suffix, regex, urlEquals
        var id: String { rawValue }
        var label: String {
            switch self {
            case .equals:    return "Equals"
            case .suffix:    return "Suffix"
            case .regex:     return "Regex"
            case .urlEquals: return "URL"
            }
        }
        var placeholder: String {
            switch self {
            case .equals:    return "api.github.com"
            case .suffix:    return "github.com"
            case .regex:     return "^.*\\.slack\\.com$"
            case .urlEquals: return "https://github.com/orgs/acme/people"
            }
        }
        /// True when the input is a full URL string rather than a host
        /// pattern. Drives validation and the eventual `urlEquals` field.
        var isExactURL: Bool { self == .urlEquals }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case open, incognito, ask, block, appScheme
        var id: String { rawValue }
        var label: String {
            switch self {
            case .open:      return "Open in"
            case .incognito: return "Open privately in"
            case .ask:       return "Always ask"
            case .block:     return "Block"
            case .appScheme: return "Open via app scheme"
            }
        }
        var needsTarget: Bool { self == .open || self == .incognito }
    }

    /// Targets the user can pick. For incognito-bound actions we filter down
    /// to browsers we know support private mode — otherwise the rule would
    /// silently fall back to the picker at routing time.
    private var pickableTargets: [LaunchOption] {
        switch actionKind {
        case .incognito:
            return options.filter { URLOpener.supportsIncognito(bundleID: $0.browser.bundleID) }
        default:
            return options
        }
    }

    private var trimmedHost: String {
        hostValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedScheme: String {
        schemeValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns nil when the form is submittable; otherwise a short message
    /// the footer can show inline. Drives both the disabled state of the
    /// Add button and the visible error text.
    private var validationError: String? {
        if trimmedHost.isEmpty {
            return hostKind == .urlEquals ? "URL can't be empty" : "Host can't be empty"
        }
        if hostKind == .regex {
            // The matcher uses `NSRegularExpression`; reject anything that
            // would silently `try?` away to a never-matching rule.
            if (try? NSRegularExpression(pattern: trimmedHost)) == nil {
                return "Invalid regular expression"
            }
        }
        if hostKind == .urlEquals {
            // Require something parseable as an absolute URL with a scheme
            // and host — otherwise the rule could never match anything the
            // matcher actually sees coming through the pipeline.
            guard let parsed = URL(string: trimmedHost),
                  let scheme = parsed.scheme, !scheme.isEmpty,
                  parsed.host?.isEmpty == false
            else {
                return "Enter a full URL including scheme (https://…)"
            }
        }
        if actionKind.needsTarget, selectedTarget == nil {
            return "Pick a target browser"
        }
        if actionKind == .appScheme, trimmedScheme.isEmpty {
            return "Scheme can't be empty (e.g. slack, zoommtg)"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            matchSection
            actionSection

            // Surface specific problems (bad regex, missing target, missing
            // scheme) once the user has actually typed a host. The "empty
            // host" case is communicated by the disabled Add button alone —
            // showing a red banner on initial render would feel accusatory.
            if !trimmedHost.isEmpty, let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }

            footer
        }
        .padding(20)
        .frame(minWidth: 440)
        .onAppear(perform: seedDefaultTarget)
        .onChange(of: actionKind) { _ in seedDefaultTarget() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.rectangle.on.folder")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add rule")
                    .font(.system(size: 15, weight: .semibold))
                Text("New rules are inserted at the top of the list.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Match section

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Match")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Match by", selection: $hostKind) {
                        ForEach(HostKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    TextField(hostKind.placeholder, text: $hostValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .disableAutocorrection(true)

                    Text(hostKindHelp)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
            }
        }
    }

    private var hostKindHelp: String {
        switch hostKind {
        case .equals:    return "Matches one specific host exactly (api.github.com)."
        case .suffix:    return "Matches that host and all of its subdomains (github.com, www.github.com, gist.github.com)."
        case .regex:     return "NSRegularExpression syntax, case-insensitive. Anchor with ^ and $ to be safe."
        case .urlEquals: return "Matches only this exact URL (scheme + host + path + query). Junction strips trackers before matching, so paste the canonical form — e.g. without utm_* params."
        }
    }

    // MARK: - Action section

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Action")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Action", selection: $actionKind) {
                        ForEach(ActionKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .labelsHidden()

                    if actionKind.needsTarget {
                        targetPicker
                    } else if actionKind == .appScheme {
                        schemeField
                    }
                }
                .padding(12)
            }
        }
    }

    private var targetPicker: some View {
        let targets = pickableTargets
        return Group {
            if targets.isEmpty {
                Text("No browsers found that support this action.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Picker("Target", selection: Binding(
                    get: { selectedTarget },
                    set: { selectedTarget = $0 }
                )) {
                    Text("Select a browser…").tag(LaunchTarget?.none)
                    ForEach(targets) { option in
                        Text(option.displayName).tag(LaunchTarget?.some(option.target))
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var schemeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("slack", text: $schemeValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .disableAutocorrection(true)
            Text("Junction will hand matching URLs to the app registered for this URL scheme.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Add rule") { submit() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundColor(.secondary)
    }

    // MARK: - Behavior

    /// Preselects the first valid target whenever the action kind flips so
    /// the user doesn't have to open a picker just to satisfy validation.
    /// Clears the selection when the new action filter removes the previous
    /// pick (e.g. switching to Incognito-only and the old target was Safari).
    private func seedDefaultTarget() {
        guard actionKind.needsTarget else {
            selectedTarget = nil
            return
        }
        let pool = pickableTargets
        if let current = selectedTarget, pool.contains(where: { $0.target == current }) {
            return
        }
        selectedTarget = pool.first?.target
    }

    private func submit() {
        guard validationError == nil else { return }

        let action: RuleAction = {
            switch actionKind {
            case .open:      return .open(selectedTarget!)
            case .incognito: return .openIncognito(selectedTarget!)
            case .ask:       return .ask
            case .block:     return .block
            case .appScheme: return .appScheme(trimmedScheme)
            }
        }()

        let rule: DomainRule
        if hostKind == .urlEquals {
            // We also seed `host` with the URL's host so the (legacy) host
            // surface in display code and `dedupKey` has something sensible
            // — even though the matcher short-circuits on `urlEquals`. Use
            // the typed form as-is for the `urlEquals` value; matching does
            // its own canonicalization, so we don't want to rewrite what
            // the user typed in the file on disk.
            let parsed = URL(string: trimmedHost)
            let host: HostMatch = .equals(parsed?.host ?? trimmedHost)
            rule = DomainRule(host: host, action: action, urlEquals: trimmedHost)
        } else {
            let host: HostMatch = {
                switch hostKind {
                case .equals:    return .equals(trimmedHost)
                case .suffix:    return .suffix(trimmedHost)
                case .regex:     return .regex(trimmedHost)
                case .urlEquals: return .equals(trimmedHost)  // unreachable
                }
            }()
            rule = DomainRule(host: host, action: action)
        }

        RulesStore.shared.addRule(rule)
        dismiss()
    }
}
