import AppKit
import CoreServices

final class MenuBarController: NSObject {
    private enum MenuTags: Int {
        case setDefaultBrowser = 71001
        case preferences = 71002
    }

    private let statusItem: NSStatusItem
    private let openPreferences: () -> Void

    init(openPreferences: @escaping () -> Void) {
        self.openPreferences = openPreferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

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

        if !DefaultWebBrowserStatus.isJunctionDefaultForHTTPAndHTTPS {
            let setDefault = NSMenuItem(
                title: "Set as Default Browser…",
                action: #selector(setAsDefault),
                keyEquivalent: ""
            )
            setDefault.tag = MenuTags.setDefaultBrowser.rawValue
            setDefault.target = self
            menu.addItem(setDefault)
        }

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

    @objc private func openPrefs() { openPreferences() }

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
        let isDefault = DefaultWebBrowserStatus.isJunctionDefaultForHTTPAndHTTPS
        let hasSetDefaultItem = menu.items.contains(where: { $0.tag == MenuTags.setDefaultBrowser.rawValue })

        if isDefault, hasSetDefaultItem {
            while let index = menu.items.firstIndex(where: { $0.tag == MenuTags.setDefaultBrowser.rawValue }) {
                menu.removeItem(at: index)
            }
        } else if !isDefault, !hasSetDefaultItem {
            guard let prefsIndex = menu.items.firstIndex(where: { $0.tag == MenuTags.preferences.rawValue }) else {
                return
            }
            let setDefault = NSMenuItem(
                title: "Set as Default Browser…",
                action: #selector(setAsDefault),
                keyEquivalent: ""
            )
            setDefault.tag = MenuTags.setDefaultBrowser.rawValue
            setDefault.target = self
            menu.insertItem(setDefault, at: prefsIndex)
        }
    }
}
