import AppKit
import SwiftUI

struct ClipboardHUDHandlers {
    var onRoute: ((URL) -> Void)?
}

final class ClipboardHUDController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?
    private var handlers = ClipboardHUDHandlers()
    private var lastPlacedHeight: CGFloat = 0
    private let autoDismissInterval: TimeInterval = 14

    private static let edgeInset: CGFloat = 22

    func configure(handlers: ClipboardHUDHandlers) {
        self.handlers = handlers
    }

    func present(url: URL) {
        dismissWork?.cancel()
        lastPlacedHeight = 0

        let panel = panel ?? makePanel()
        self.panel = panel

        let view = ClipboardHUDView(
            url: url,
            handlers: handlers,
            onDismiss: { [weak self] in self?.dismiss(animated: true) },
            onHoverChanged: { [weak self] hovering in
                self?.setHoverPaused(hovering)
            },
            onPreferredSize: { [weak self] size in
                self?.resizePanel(to: size)
            }
        )
        let host = NSHostingView(rootView: view)
        Self.configureTransparentHosting(host)
        // `panel.contentView = host` makes the panel auto-size the hosting
        // view to its content rect via the default autoresizing mask, so we
        // don't add manual constraints (those would self-reference once host
        // becomes contentView) and we don't disable the autoresizing mask.
        panel.contentView = host

        placeTopRight(panel, size: panel.frame.size, animate: false)
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        scheduleDismiss(after: autoDismissInterval)
    }

    private static func configureTransparentHosting<Content: View>(_ host: NSHostingView<Content>) {
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.cornerRadius = ClipboardHUDMetrics.cornerRadius
        host.layer?.masksToBounds = true
    }

    private func setHoverPaused(_ hovering: Bool) {
        if hovering {
            dismissWork?.cancel()
        } else {
            scheduleDismiss(after: autoDismissInterval)
        }
    }

    private func scheduleDismiss(after interval: TimeInterval) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func dismiss(animated: Bool) {
        dismissWork?.cancel()
        guard let panel else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    private func resizePanel(to size: CGSize) {
        guard let panel else { return }
        let height = max(88, size.height)
        let animate = abs(height - lastPlacedHeight) > 2
        lastPlacedHeight = height
        placeTopRight(
            panel,
            size: NSSize(width: ClipboardHUDMetrics.cardWidth, height: height),
            animate: animate
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: ClipboardHUDMetrics.cardWidth, height: 120),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        return panel
    }

    private func placeTopRight(_ panel: NSPanel, size: NSSize, animate: Bool) {
        let frame = Self.topRightFrame(size: size, on: NSScreen.main)
        if animate {
            panel.animator().setFrame(frame, display: true)
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private static func topRightFrame(size: NSSize, on screen: NSScreen?) -> NSRect {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else {
            return NSRect(x: 120, y: 120, width: size.width, height: size.height)
        }
        var origin = NSPoint(
            x: visible.maxX - size.width - edgeInset,
            y: visible.maxY - size.height - edgeInset
        )
        if origin.y + size.height > visible.maxY - edgeInset {
            origin.y = visible.maxY - size.height - edgeInset
        }
        if origin.x < visible.minX + edgeInset { origin.x = visible.minX + edgeInset }
        if origin.y < visible.minY + edgeInset { origin.y = visible.minY + edgeInset }
        return NSRect(origin: origin, size: size)
    }
}
