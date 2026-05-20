import AppKit
import SwiftUI

final class PostDefaultTourOverlayController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    var onDismiss: (() -> Void)?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PostDefaultTourView(onDismiss: { [weak self] in
            self?.window?.close()
        })
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Junction is your default browser"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 520, height: 400))
        window.minSize = NSSize(width: 520, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onDismiss?()
    }
}

private struct PostDefaultTourView: View {
    let onDismiss: () -> Void
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Junction is your default browser")
                    .font(.system(size: 20, weight: .semibold))
                Text("Every link click now routes through Junction. Here's what you can do.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider().opacity(0.2)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    bullet(
                        icon: "arrow.triangle.branch",
                        title: "Route by site",
                        detail: "Open Preferences → Rules to send github.com to your work browser and everything else to your personal one."
                    )
                    bullet(
                        icon: "person.2",
                        title: "Use browser profiles",
                        detail: "If Chrome or Edge has multiple profiles, each appears as a separate tile in the picker."
                    )
                    bullet(
                        icon: "sparkles",
                        title: "Tracker cleanup is on",
                        detail: "utm_*, fbclid, and other tracking parameters are stripped before the browser sees the URL."
                    )
                    bullet(
                        icon: "keyboard",
                        title: "Keyboard shortcuts",
                        detail: "The picker footer shows the essentials; click ? Shortcuts (or press ?) for the rest."
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 22)
            }

            Divider().opacity(0.2)

            HStack {
                Spacer()
                Button("Get Started") { onDismiss() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 400)
        .tint(settings.settings.accentPreset.swiftUIColor)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        )
    }

    private func bullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
