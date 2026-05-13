import AppKit
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

final class PickerPanelController {
    private var panel: NSPanel?
    private var hosting: NSHostingView<PickerView>?
    private var resignMonitor: Any?
    private var globalClickMonitor: Any?

    func present(url: URL, context: RouteContext) {
        let openOnce: (LaunchOption) -> Void = { option in
            let cleaned = SettingsStore.shared.settings.cleanURLsBeforeOpening
            let urlToOpen = cleaned ? URLTransformers.default.run(url) : url
            URLOpener.open(urlToOpen, with: option)
        }

        let options = LaunchOptionDiscovery.visibleOptions()
        let model = PickerViewModel(
            url: url,
            options: options,
            context: context,
            onPick: { [weak self] option, remember in
                if remember, let host = RulesStore.normalizedHost(for: url) {
                    RulesStore.shared.remember(target: option.target, forHost: host)
                }
                openOnce(option)
                self?.dismiss()
            },
            onPickMulti: { [weak self] options in
                for option in options { openOnce(option) }
                self?.dismiss()
            },
            onCancel: { [weak self] in self?.dismiss() }
        )

        let width = PickerView.desiredWidth(forOptionCount: options.count)
        let view = PickerView(model: model, width: width)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 300),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.worksWhenModal = true
        panel.contentView = host

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                host.topAnchor.constraint(equalTo: contentView.topAnchor),
                host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.hosting = host

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.dismiss()
        }

        resignMonitor = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        if let token = globalClickMonitor {
            NSEvent.removeMonitor(token)
            globalClickMonitor = nil
        }
        if let token = resignMonitor {
            NotificationCenter.default.removeObserver(token)
            resignMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }
}
