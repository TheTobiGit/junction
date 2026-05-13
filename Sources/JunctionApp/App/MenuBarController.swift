import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let openPreferences: () -> Void
    private let openOnboarding: () -> Void

    init(openPreferences: @escaping () -> Void, openOnboarding: @escaping () -> Void) {
        self.openPreferences = openPreferences
        self.openOnboarding = openOnboarding
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Junction")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Junction"
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Junction", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let summon = NSMenuItem(
            title: "Open Clipboard Link…",
            action: #selector(pasteAndOpen),
            keyEquivalent: ""
        )
        summon.target = self
        menu.addItem(summon)

        let reroute = NSMenuItem(
            title: "Reroute Last Link…",
            action: #selector(rerouteLast),
            keyEquivalent: ""
        )
        reroute.target = self
        menu.addItem(reroute)

        menu.addItem(.separator())

        let setDefault = NSMenuItem(
            title: "Set as Default Browser…",
            action: #selector(setAsDefault),
            keyEquivalent: ""
        )
        setDefault.target = self
        menu.addItem(setDefault)

        let onboarding = NSMenuItem(
            title: "Run Setup Again…",
            action: #selector(runOnboarding),
            keyEquivalent: ""
        )
        onboarding.target = self
        menu.addItem(onboarding)

        let prefs = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPrefs),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        let openRules = NSMenuItem(
            title: "Open Rules File…",
            action: #selector(openRulesFile),
            keyEquivalent: "r"
        )
        openRules.keyEquivalentModifierMask = [.command, .shift]
        openRules.target = self
        menu.addItem(openRules)

        let revealRules = NSMenuItem(
            title: "Reveal Rules in Finder",
            action: #selector(revealRulesFile),
            keyEquivalent: ""
        )
        revealRules.target = self
        menu.addItem(revealRules)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Junction",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openPrefs() { openPreferences() }

    @objc private func runOnboarding() { openOnboarding() }

    @objc private func pasteAndOpen() {
        guard let raw = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return }
        var url = URL(string: raw)
        if url?.scheme == nil, raw.contains(".") {
            url = URL(string: "https://" + raw)
        }
        guard let target = url else { return }
        NSWorkspace.shared.open(URL(string: "junction://open?ask=1&url=" + (target.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))!)
    }

    @objc private func rerouteLast() {
        guard let url = LastURLStore.shared.mostRecent else { return }
        let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        NSWorkspace.shared.open(URL(string: "junction://open?ask=1&url=" + encoded)!)
    }

    @objc private func openRulesFile() {
        let url = RulesStore.shared.fileURL
        NSWorkspace.shared.open(url)
    }

    @objc private func revealRulesFile() {
        let url = RulesStore.shared.fileURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func setAsDefault() {
        let bid = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        LSSetDefaultHandlerForURLScheme("http" as CFString, bid as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bid as CFString)

        let alert = NSAlert()
        alert.messageText = "Default handler requested"
        alert.informativeText = "macOS may show a confirmation dialog. If it does not appear, open System Settings > Desktop & Dock and set Junction as the default web browser."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
