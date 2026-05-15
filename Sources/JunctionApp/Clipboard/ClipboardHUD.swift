import AppKit
import SwiftUI

final class ClipboardHUDController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    func present(url: URL) {
        dismissWork?.cancel()

        let panel = panel ?? makePanel()
        self.panel = panel

        let view = ClipboardHUDView(url: url, onDismiss: { [weak self] in self?.dismiss() })
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                host.topAnchor.constraint(equalTo: contentView.topAnchor),
                host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        positionInTopRight(panel)
        panel.orderFront(nil)

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func dismiss() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 92),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        return panel
    }

    private func positionInTopRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.maxX - panel.frame.width - 16,
            y: frame.maxY - panel.frame.height - 16
        )
        panel.setFrameOrigin(origin)
    }
}

struct ClipboardHUDView: View {
    let url: URL
    let onDismiss: () -> Void
    @ObservedObject private var appSettings = SettingsStore.shared

    private var cleaned: URL {
        URLTransformers.default.run(url)
    }

    private var didClean: Bool {
        cleaned.absoluteString != url.absoluteString
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Link copied")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(cleaned.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                if didClean {
                    Text("cleaned")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }

            Spacer(minLength: 6)

            Button {
                copyCleaned()
                onDismiss()
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .buttonStyle(.borderless)
            .help("Copy cleaned")

            Button {
                NSWorkspace.shared.open(cleaned)
                onDismiss()
            } label: {
                Image(systemName: "arrow.up.forward.app.fill")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
            .help("Route now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            JunctionChromeBackground(
                theme: appSettings.settings.chromeTheme,
                accent: appSettings.settings.accentPreset.swiftUIColor
            )
        )
        .tint(appSettings.settings.accentPreset.swiftUIColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func copyCleaned() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cleaned.absoluteString, forType: .string)
    }
}
