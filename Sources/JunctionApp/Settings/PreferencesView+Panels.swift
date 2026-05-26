import AppKit
import SwiftUI

// MARK: - Redirects panel

extension PreferencesView {
    var rewritesPanel: some View {
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
}

// MARK: - Apps panel

extension PreferencesView {
    var appSchemesPanel: some View {
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
}

// MARK: - Shortcuts panel

extension PreferencesView {
    var hotkeysPanel: some View {
        PrefsBlock {
            hotkeyRow("Open picker", binding: hotkeyBinding(\.summonPicker))
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
}

// MARK: - Tracking panel

extension PreferencesView {
    var trackersPanel: some View {
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
}
