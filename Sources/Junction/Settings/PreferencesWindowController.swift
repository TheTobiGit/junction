import AppKit
import SwiftUI

final class PreferencesWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView()
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Junction Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 680, height: 540))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct PreferencesView: View {
    @State private var options: [LaunchOption] = []
    @State private var rulesFile: RulesFile = RulesStore.shared.rules
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            rewritesTab
                .tabItem { Label("Rewrites", systemImage: "arrow.triangle.2.circlepath") }
            targetsTab
                .tabItem { Label("Targets", systemImage: "globe") }
            rulesTab
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 480)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .junctionRulesChanged)) { _ in
            reload()
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Link handling").font(.headline)

            Toggle(isOn: $settings.settings.cleanURLsBeforeOpening) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clean URLs before opening")
                        .font(.system(size: 13, weight: .medium))
                    Text("Removes tracking parameters (utm_*, fbclid, gclid, and similar) from links before they are handed to the browser.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $settings.settings.expandShortenedURLs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expand shortened URLs")
                        .font(.system(size: 13, weight: .medium))
                    Text("Resolves t.co, bit.ly, lnkd.in, and similar shorteners before routing (HEAD request with 2s timeout).")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $settings.settings.clipboardWatcherEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch the clipboard for links")
                        .font(.system(size: 13, weight: .medium))
                    Text("When you copy a URL, show a small HUD in the corner to clean, save, or route it without clicking the original link.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var rewritesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Domain rewrites").font(.headline)
                Spacer()
                Button {
                    settings.settings.redirects.append(
                        DomainRedirect(fromHost: "example.com", toHost: "example.net", enabled: true, label: nil)
                    )
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            Text("Rewrites replace a URL's host before routing. Disabled rules are ignored.")
                .foregroundColor(.secondary)
                .font(.callout)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach($settings.settings.redirects) { $redirect in
                        redirectRow(redirect: $redirect)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 260)
        }
    }

    private func redirectRow(redirect: Binding<DomainRedirect>) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: redirect.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
            TextField("from-host", text: redirect.fromHost)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 140)
            Image(systemName: "arrow.right").foregroundColor(.secondary)
            TextField("to-host", text: redirect.toHost)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 140)
            if let label = redirect.wrappedValue.label {
                Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if let idx = settings.settings.redirects.firstIndex(where: { $0.id == redirect.wrappedValue.id }) {
                    settings.settings.redirects.remove(at: idx)
                }
            } label: {
                Image(systemName: "trash").foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    private var targetsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected targets").font(.headline)
                Spacer()
                Text("\(visibleCount) of \(options.count) visible")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text("Junction discovers installed browsers and their profiles. Uncheck a target to hide it from the picker, or drag rows to reorder how they appear. Hidden targets still work for saved rules and the Batch window.")
                .foregroundColor(.secondary)
                .font(.callout)

            HStack(spacing: 8) {
                Button("Show all") { setAllHidden(false) }
                    .disabled(visibleCount == options.count)
                Button("Hide all") { setAllHidden(true) }
                    .disabled(visibleCount == 0)
                Button("Reset order") { resetOrder() }
                    .disabled(settings.settings.targetOrder.isEmpty)
                Spacer()
            }
            .font(.system(size: 11))

            List {
                Section {
                    if visibleTargets.isEmpty {
                        Text("No visible targets — enable at least one below.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleTargets) { option in
                            targetRow(option)
                                .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                .listRowSeparator(.hidden)
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
                                .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                .listRowSeparator(.hidden)
                        }
                        .onMove(perform: moveHidden)
                    } header: {
                        sectionHeader("Hidden", count: hiddenTargets.count)
                    }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 260)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var visibleCount: Int {
        visibleTargets.count
    }

    private func targetRow(_ option: LaunchOption) -> some View {
        let key = option.target.storageKey
        let isHidden = settings.settings.hiddenTargetKeys.contains(key)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .help("Drag to reorder")

            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { settings.setHidden(!$0, for: key) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: option.icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .opacity(isHidden ? 0.4 : 1.0)
                if let hex = option.colorHex, let color = Color(hexString: hex) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                        .opacity(isHidden ? 0.4 : 1.0)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(option.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isHidden ? .secondary : .primary)
                Text(option.target.storageKey)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isHidden {
                Text("Hidden")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.18)))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
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

    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rules").font(.headline)
                Spacer()
                Menu("Import recipe") {
                    ForEach(RuleRecipes.all) { recipe in
                        Button(recipe.name) {
                            RulesStore.shared.importRecipe(recipe)
                        }
                    }
                }
                Button("Open rules file") { NSWorkspace.shared.open(RulesStore.shared.fileURL) }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([RulesStore.shared.fileURL])
                }
            }
            Text("Rules are evaluated top to bottom; the first match wins. Edit them here or open the JSON file directly. Changes on disk hot-reload.")
                .foregroundColor(.secondary)
                .font(.callout)

            rulesList
            fallbackRow
        }
    }

    private var rulesList: some View {
        Group {
            if rulesFile.rules.isEmpty {
                VStack(spacing: 6) {
                    Text("No rules yet").font(.system(size: 14, weight: .medium))
                    Text("Use the Remember toggle in the picker, or edit the rules file directly.")
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(rulesFile.rules) { rule in
                            ruleRow(rule)
                        }
                    }
                }
                .frame(minHeight: 260)
            }
        }
    }

    private func ruleRow(_ rule: DomainRule) -> some View {
        HStack(spacing: 10) {
            Text(rule.host.kindLabel)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.18)))
                .foregroundColor(.secondary)

            Text(rule.host.displayValue)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            Spacer()

            actionLabel(rule.action)

            Button {
                RulesStore.shared.remove(ruleID: rule.id)
            } label: {
                Image(systemName: "trash").foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    private func actionLabel(_ action: RuleAction) -> some View {
        HStack(spacing: 6) {
            switch action {
            case .ask:
                Image(systemName: "questionmark.circle")
                Text("Always ask")
                    .font(.system(size: 12, weight: .medium))
            case .open(let target):
                if let opt = options.first(where: { $0.target == target }) {
                    Image(nsImage: opt.icon).resizable().frame(width: 14, height: 14)
                    Text(opt.displayName).font(.system(size: 12))
                    if let hex = opt.colorHex, let color = Color(hexString: hex) {
                        Circle().fill(color).frame(width: 8, height: 8)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(target.storageKey).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private var fallbackRow: some View {
        HStack {
            Text("Fallback").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            actionLabel(rulesFile.fallback)
            Spacer()
            Menu("Change") {
                Button("Always ask") { RulesStore.shared.setFallback(.ask) }
                Divider()
                ForEach(options) { option in
                    Button(option.displayName) {
                        RulesStore.shared.setFallback(.open(option.target))
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 90)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.08)))
    }

    private func reload() {
        options = LaunchOptionDiscovery.options()
        rulesFile = RulesStore.shared.rules
    }
}
