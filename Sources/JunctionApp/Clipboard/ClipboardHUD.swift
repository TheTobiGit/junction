import AppKit
import SwiftUI

private struct ClipboardHUDSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

struct ClipboardHUDView: View {
    let url: URL
    let handlers: ClipboardHUDHandlers
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onPreferredSize: (CGSize) -> Void

    @ObservedObject private var appSettings = SettingsStore.shared
    @StateObject private var model: ClipboardHUDViewModel
    @State private var appeared = false
    @State private var showRiskDetail = false

    init(
        url: URL,
        handlers: ClipboardHUDHandlers,
        onDismiss: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onPreferredSize: @escaping (CGSize) -> Void
    ) {
        self.url = url
        self.handlers = handlers
        self.onDismiss = onDismiss
        self.onHoverChanged = onHoverChanged
        self.onPreferredSize = onPreferredSize
        _model = StateObject(wrappedValue: ClipboardHUDViewModel(url: url))
    }

    private var accent: Color { appSettings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { appSettings.settings.chromeTheme }

    var body: some View {
        PickerGlassPanel(
            theme: theme,
            accent: accent,
            cornerRadius: ClipboardHUDMetrics.cornerRadius,
            subtle: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                identityRow
                urlField
                actionBar
                if model.showQR {
                    qrRow
                }
            }
            .padding(12)
        }
        .frame(width: ClipboardHUDMetrics.cardWidth)
        .shadow(color: .black.opacity(0.34), radius: 18, y: 7)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.98, anchor: .topTrailing)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ClipboardHUDSizeKey.self, value: proxy.size)
            }
        }
        .onPreferenceChange(ClipboardHUDSizeKey.self, perform: onPreferredSize)
        .onHover(perform: onHoverChanged)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                appeared = true
            }
        }
    }

    private var identityRow: some View {
        HStack(spacing: 8) {
            statusDot
            FaviconView(data: model.faviconData, fallbackSize: 9)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(model.displayHost)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                copyMenu
                ClipboardHUDIconButton(symbol: "xmark", help: "Dismiss", action: onDismiss)
            }
        }
    }

    private var statusDot: some View {
        Button {
            if model.linkStatus == .caution { showRiskDetail.toggle() }
        } label: {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
        }
        .buttonStyle(.plain)
        .help(model.statusHelp)
        .popover(isPresented: $showRiskDetail, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.riskFlags) { flag in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flag.title).font(.system(size: 12, weight: .semibold))
                        Text(flag.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }

    private var statusColor: Color {
        switch model.linkStatus {
        case .ok: return Color.white.opacity(0.32)
        case .cleaned: return accent
        case .caution: return .orange
        case .blocked: return .red
        }
    }

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.openURL.absoluteString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.72))
                .lineLimit(model.urlExpanded ? 3 : 1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .onTapGesture(count: 2) { model.urlExpanded.toggle() }
            HStack(spacing: 8) {
                if let feedback = model.copyFeedback {
                    Text(feedback)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(copyFeedbackTint(for: feedback))
                }
                if model.isShortened {
                    if model.isExpanding {
                        Text("Expanding…")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Expand short link", action: model.expandShortener)
                            .font(.system(size: 9, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(accent)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func copyFeedbackTint(for message: String) -> Color {
        if message.contains("review") { return .orange }
        if message.contains("cleaned") { return accent }
        return .secondary
    }

    private var copyMenu: some View {
        Menu {
            Button("Copy cleaned link", action: model.copyCleaned)
            if model.didClean {
                Button("Copy original link", action: model.copyOriginalLink)
            }
        } label: {
            ClipboardHUDIconButton(symbol: "doc.on.doc", help: "Copy link")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var routeURL: URL { model.sourceURL }

    private var actionBar: some View {
        HStack(spacing: 6) {
            Button {
                handlers.onRoute?(routeURL)
                onDismiss()
            } label: {
                Text("Open")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(height: ClipboardHUDMetrics.actionHeight)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent))
            .help("Opens via your rules, or the picker when you still need to choose")
            .disabled(model.matchedAction == .block)

            HStack(spacing: 2) {
                ClipboardHUDIconButton(
                    symbol: "qrcode",
                    help: "Send to phone",
                    isActive: model.showQR,
                    accent: accent
                ) {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        model.toggleQR()
                    }
                }
                moreMenu
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
    }

    private var moreMenu: some View {
        Menu {
            if model.matchedAction != .block {
                Button("Open in default browser") {
                    NSWorkspace.shared.open(model.openURL)
                    onDismiss()
                }
            }
            Button("Copy domain", action: model.copyDomain)
            Divider()
            Button("Share…") { shareOpenURL() }
        } label: {
            ClipboardHUDIconButton(symbol: "ellipsis", help: "More")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var qrRow: some View {
        HStack(spacing: 10) {
            ClipboardQRPlate(image: model.qrImage, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text("Send to phone").font(.system(size: 11, weight: .semibold))
                Text("Scan to open this link")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func shareOpenURL() {
        let picker = NSSharingServicePicker(items: [model.openURL as NSURL])
        let anchor: NSView = {
            if let panel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible }),
               let view = panel.contentView {
                return view
            }
            return NSApp.keyWindow?.contentView ?? NSView()
        }()
        picker.show(relativeTo: .zero, of: anchor, preferredEdge: .minY)
    }
}
