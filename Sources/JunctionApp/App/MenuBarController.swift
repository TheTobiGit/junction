import AppKit
import CoreServices

final class MenuBarController: NSObject {
    private enum MenuTags: Int {
        case setDefaultBrowser = 71001
        case preferences = 71002
        case recent = 71003
    }

    private let statusItem: NSStatusItem
    private let openPreferences: (PreferencesFocusTarget?) -> Void
    private let routeURL: (URL) -> Void
    private weak var dropOverlay: StatusItemDropOverlay?

    init(openPreferences: @escaping (PreferencesFocusTarget?) -> Void, routeURL: @escaping (URL) -> Void) {
        self.openPreferences = openPreferences
        self.routeURL = routeURL
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Junction")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Junction — drop a link to route it"

            // Drag-and-drop overlay: a transparent NSView pinned over the
            // status button accepts URL drops and forwards them to our router,
            // so users can drag a link from any app onto the menu bar item.
            let overlay = StatusItemDropOverlay { [weak self] url in
                self?.routeURL(url)
            }
            overlay.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: button.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            self.dropOverlay = overlay
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Junction", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        if !DefaultWebBrowserStatus.current.isJunctionDefaultForHTTPAndHTTPS {
            let setDefault = NSMenuItem(
                title: "Set as Default Browser…",
                action: #selector(setAsDefault),
                keyEquivalent: ""
            )
            setDefault.tag = MenuTags.setDefaultBrowser.rawValue
            setDefault.target = self
            menu.addItem(setDefault)
        }

        let openURL = NSMenuItem(
            title: "Open URL…",
            action: #selector(openURLPrompt),
            keyEquivalent: "o"
        )
        openURL.target = self
        menu.addItem(openURL)

        let recent = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recent.tag = MenuTags.recent.rawValue
        recent.submenu = makeRecentSubmenu()
        menu.addItem(recent)

        let prefs = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPrefs),
            keyEquivalent: ","
        )
        prefs.tag = MenuTags.preferences.rawValue
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Junction",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func makeRecentSubmenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        let entries = Array(RoutingHistory.shared.entries.prefix(10))
        if entries.isEmpty {
            let empty = NSMenuItem(title: "No recent links", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return menu
        }
        for entry in entries {
            let item = NSMenuItem(
                title: trimmedTitle(for: entry.cleanedURL),
                action: #selector(routeRecent(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = entry.cleanedURL
            item.toolTip = entry.didClean
                ? "Original: \(entry.originalURL)\nCleaned:  \(entry.cleanedURL)"
                : entry.cleanedURL
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let openActivity = NSMenuItem(
            title: "Show All in Preferences…",
            action: #selector(openPrefsActivity),
            keyEquivalent: ""
        )
        openActivity.target = self
        menu.addItem(openActivity)
        return menu
    }

    private func trimmedTitle(for raw: String) -> String {
        let max = 64
        guard raw.count > max else { return raw }
        let head = raw.prefix(40)
        let tail = raw.suffix(20)
        return "\(head)…\(tail)"
    }

    @objc private func openPrefs() { openPreferences(nil) }

    @objc private func openPrefsActivity() { openPreferences(.activity) }

    @objc private func openURLPrompt() {
        let alert = NSAlert()
        alert.messageText = "Open a URL through Junction"
        alert.informativeText = "Paste any URL. Junction will clean and route it as if you'd clicked it."
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "https://…"
        if let pasteboardString = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           pasteboardString.hasPrefix("http://") || pasteboardString.hasPrefix("https://") {
            field.stringValue = pasteboardString
        }
        alert.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        var raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        if !raw.contains("://"), raw.contains(".") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            let warn = NSAlert()
            warn.messageText = "That doesn't look like a URL"
            warn.informativeText = raw
            warn.addButton(withTitle: "OK")
            warn.alertStyle = .warning
            warn.runModal()
            return
        }
        routeURL(url)
    }

    @objc private func routeRecent(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let url = URL(string: raw)
        else { return }
        routeURL(url)
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
        rebuildMenu()
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Refresh the Recent submenu lazily so re-opening the menu always shows current entries.
        if let recent = menu.items.first(where: { $0.tag == MenuTags.recent.rawValue }) {
            recent.submenu = makeRecentSubmenu()
        }

        let isDefault = DefaultWebBrowserStatus.current.isJunctionDefaultForHTTPAndHTTPS
        let hasSetDefaultItem = menu.items.contains(where: { $0.tag == MenuTags.setDefaultBrowser.rawValue })

        if isDefault, hasSetDefaultItem {
            while let index = menu.items.firstIndex(where: { $0.tag == MenuTags.setDefaultBrowser.rawValue }) {
                menu.removeItem(at: index)
            }
        } else if !isDefault, !hasSetDefaultItem {
            guard let recentIndex = menu.items.firstIndex(where: { $0.tag == MenuTags.recent.rawValue }) else {
                return
            }
            let setDefault = NSMenuItem(
                title: "Set as Default Browser…",
                action: #selector(setAsDefault),
                keyEquivalent: ""
            )
            setDefault.tag = MenuTags.setDefaultBrowser.rawValue
            setDefault.target = self
            menu.insertItem(setDefault, at: recentIndex)
        }
    }
}
