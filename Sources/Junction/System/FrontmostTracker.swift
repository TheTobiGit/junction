import AppKit

struct URLSource {
    let bundleID: String
    let name: String
    let icon: NSImage?
}

final class FrontmostTracker {
    static let shared = FrontmostTracker()

    private(set) var lastNonJunction: URLSource?
    private let ownBundleID = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"

    private init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        if let front = NSWorkspace.shared.frontmostApplication {
            captureIfPossible(front)
        }
    }

    @objc private func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        captureIfPossible(app)
    }

    private func captureIfPossible(_ app: NSRunningApplication) {
        guard let bid = app.bundleIdentifier, bid != ownBundleID else { return }
        let name = app.localizedName ?? bid
        lastNonJunction = URLSource(bundleID: bid, name: name, icon: app.icon)
    }
}
