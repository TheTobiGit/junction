import AppKit
import SwiftUI
import Combine

private extension CGRect {
    var area: CGFloat { width * height }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

final class PickerPanelController {
    enum DismissReason {
        case userPicked
        case userCancelled
        case clickedOutside
        case resignedKey
    }

    private static let screenInsets: CGFloat = 8

    private var panel: NSPanel?
    private var hosting: NSHostingView<PickerView>?
    private var resignMonitor: Any?
    private var globalClickMonitor: Any?
    private var moveObserver: Any?
    private var previewObserver: AnyCancellable?
    private var pickerSize: CGSize = .zero
    private var isDismissed: Bool = false
    private var isInPreviewMode: Bool = false

    func present(url: URL, context: RouteContext, onOpenPreferences: (() -> Void)? = nil) {
        if panel != nil { dismiss(reason: .userCancelled) }
        isDismissed = false

        let openOnce: (LaunchOption, Bool) -> Void = { option, incognito in
            // Resolve the cleaning flag the same way ``AppDelegate.routeAfterExpansion``
            // does so picker-confirmed opens behave identically to rule-driven
            // opens. Match before global tracker stripping so query-scoped rules
            // and per-rule tracker overrides are found correctly.
            let globalSettings = SettingsStore.shared.settings
            let globalTrace = URLTransformers.default.runTraced(url)
            let match = RulesStore.shared.match(
                url: URLTransformers.urlForRuleMatching(url),
                context: context
            )
            let trace: URLTransformResult
            if let ruleOverrides = match.rule?.trackerOverrides {
                trace = URLTransformers.pipeline(
                    globalOverrides: globalSettings.trackerOverrides,
                    ruleOverrides: ruleOverrides
                ).runTraced(url)
            } else {
                trace = globalTrace
            }
            let shouldClean = DomainRule.resolveCleanFlag(
                rule: match.rule,
                globalEnabled: globalSettings.cleanURLsBeforeOpening
            )
            let urlToOpen = shouldClean ? trace.final : url
            URLOpener.open(urlToOpen, with: option, incognito: incognito) { success in
                if success {
                    LastURLStore.shared.recordRouted(urlToOpen)
                    // Picker-confirmed opens are the most common interactive
                    // path; without this entry, the Activity tab would only
                    // see rule-driven and CLI opens.
                    RoutingHistory.shared.record(
                        originalURL: url,
                        result: trace,
                        outcome: incognito ? .openedIncognito : .opened,
                        targetBundleID: option.browser.bundleID,
                        ruleLabel: "picker",
                        openedURL: urlToOpen,
                        sourceBundleID: context.source?.bundleID,
                        targetStorageKey: option.target.storageKey
                    )
                }
            }
        }

        let options = LaunchOptionDiscovery.visibleOptions()
        let model = PickerViewModel(
            url: url,
            options: options,
            context: context,
            onPick: { [weak self] option, remember, incognito in
                if remember, let host = RulesStore.normalizedHost(for: url) {
                    let action: RuleAction = incognito ? .openIncognito(option.target) : .open(option.target)
                    RulesStore.shared.addRule(host: .equals(host), action: action)
                }
                openOnce(option, incognito)
                self?.dismiss(reason: .userPicked)
            },
            onPickMulti: { [weak self] options, incognito in
                for option in options { openOnce(option, incognito) }
                self?.dismiss(reason: .userPicked)
            },
            onCancel: { [weak self] in self?.dismiss(reason: .userCancelled) },
            onOpenPreferences: onOpenPreferences
        )

        LastURLStore.shared.recordPicker(url)
        PreviewWebViewFactory.warmup()

        let style = SettingsStore.shared.settings.pickerStyle
        let size = PickerView.desiredSize(forOptionCount: options.count, style: style)
        let view = PickerView(model: model, width: size.width, height: size.height)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
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
        // List style draws a detached shortcut dock inside a transparent
        // borderless panel. AppKit's window shadow is based on the panel's
        // transparent content rect, which creates a visible dark outline
        // around the floating dock/gap. Keep the system shadow for the compact
        // tile picker, but let list style rely on its SwiftUI chrome.
        panel.hasShadow = style != .list
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

        let savedFrame = SettingsStore.shared.settings.pickerFrame
        if let saved = savedFrame {
            let desiredFrame = Self.restoredFrame(from: saved, currentSize: size)
            let clamped = clampToScreen(desiredFrame)
            panel.setFrame(clamped, display: true)
        } else {
            panel.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.hosting = host
        self.pickerSize = size
        self.isInPreviewMode = false

        previewObserver = model.$previewMode
            .removeDuplicates()
            .sink { [weak self] inPreview in
                self?.isInPreviewMode = inPreview
                self?.resize(forPreview: inPreview)
            }

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.persistPickerFrame()
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.dismiss(reason: .clickedOutside)
        }

        resignMonitor = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss(reason: .resignedKey)
        }
    }

    private func resize(forPreview inPreview: Bool) {
        guard let panel else { return }
        let target: CGSize = inPreview ? PickerView.previewSize() : pickerSize
        let current = panel.frame
        let newOrigin = NSPoint(
            x: current.midX - target.width / 2,
            y: current.midY - target.height / 2
        )
        let newFrame = NSRect(origin: newOrigin, size: target)
        let clamped = clampToScreen(newFrame)
        panel.animator().setFrame(clamped, display: true, animate: true)
    }

    func clampToScreen(_ frame: NSRect, screens: [NSScreen] = NSScreen.screens) -> NSRect {
        let inset = Self.screenInsets
        let candidates = screens.isEmpty ? [NSScreen.main].compactMap { $0 } : screens

        for screen in candidates where screen.visibleFrame.contains(frame) {
            return frame
        }

        let target = candidates.max(by: {
            $0.visibleFrame.intersection(frame).area < $1.visibleFrame.intersection(frame).area
        }) ?? candidates.first

        guard let visible = target?.visibleFrame else { return frame }

        var out = frame
        if out.width > visible.width { out.size.width = visible.width }
        if out.height > visible.height { out.size.height = visible.height }
        if out.minX < visible.minX { out.origin.x = visible.minX + inset }
        if out.minY < visible.minY { out.origin.y = visible.minY + inset }
        if out.maxX > visible.maxX { out.origin.x = visible.maxX - out.width - inset }
        if out.maxY > visible.maxY { out.origin.y = visible.maxY - out.height - inset }
        return out
    }

    static func restoredFrame(from savedFrame: CGRect, currentSize: CGSize) -> CGRect {
        CGRect(origin: savedFrame.origin, size: currentSize)
    }

    func dismiss() {
        dismiss(reason: .userCancelled)
    }

    func dismiss(reason: DismissReason) {
        guard !isDismissed else { return }
        isDismissed = true
        _ = reason

        persistPickerFrame()

        previewObserver?.cancel()
        previewObserver = nil
        if let token = globalClickMonitor {
            NSEvent.removeMonitor(token)
            globalClickMonitor = nil
        }
        if let token = resignMonitor {
            NotificationCenter.default.removeObserver(token)
            resignMonitor = nil
        }
        if let token = moveObserver {
            NotificationCenter.default.removeObserver(token)
            moveObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    private func persistPickerFrame() {
        guard !isInPreviewMode, let panel else { return }
        let frame = CGRect(origin: panel.frame.origin, size: pickerSize)
        SettingsStore.shared.settings.pickerFrame = frame
    }
}
