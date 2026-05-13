import SwiftUI
import WebKit
import AppKit

struct PreviewView: View {
    @ObservedObject var model: PickerViewModel

    var body: some View {
        VStack(spacing: 0) {
            webArea
            Divider().opacity(0.12)
            bottomChrome
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }

    private var webArea: some View {
        ZStack(alignment: .top) {
            WebContainer(
                url: model.cleanedURL,
                title: $model.previewTitle,
                isLoading: $model.previewLoading,
                progress: $model.previewProgress
            )
            .background(Color.black.opacity(0.25))

            VStack(spacing: 0) {
                loadingBar
                HStack(alignment: .top) {
                    backButton
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(true)
        }
    }

    private var loadingBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(model.previewProgress))
                    .animation(.easeOut(duration: 0.18), value: model.previewProgress)
            }
        }
        .frame(height: 2)
        .opacity(model.previewLoading || model.previewProgress < 1.0 ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: model.previewLoading)
    }

    private var backButton: some View {
        FloatingIconButton(
            systemName: "chevron.left",
            help: "Back to picker (␣ or Esc)"
        ) {
            model.exitPreview()
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            titleStrip
            browserDock
            hintBar
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var titleStrip: some View {
        HStack(spacing: 10) {
            linkIcon
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(model.previewTitle ?? model.preview?.title ?? model.displayHost)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("·")
                .foregroundColor(.secondary.opacity(0.6))

            Text(model.cleanedURL.absoluteString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button {
                model.copyCleanedURL()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Copy cleaned URL (⌘C)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var browserDock: some View {
        let options = model.filteredOptions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.element.id) { idx, option in
                    DockTile(
                        option: option,
                        number: idx + 1,
                        selected: idx == model.selectedIndex
                    )
                    .onTapGesture {
                        let flags = NSEvent.modifierFlags
                        let incognito = flags.contains(.option) || model.incognitoMode
                        model.pick(option, incognito: incognito)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var hintBar: some View {
        HStack(spacing: 12) {
            hintKey("␣", "Close")
            hintKey("⏎", "Open")
            hintKey("1-9", "Switch")
            hintKey("⌘C", "Copy")
            hintKey("⌥", "Private")
            Spacer(minLength: 0)
            if model.previewLoading {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.45)
                        .frame(width: 12, height: 12)
                    Text("Loading")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.22))
    }

    private func hintKey(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var linkIcon: some View {
        if let data = model.preview?.faviconData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: "globe")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct FloatingIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary.opacity(0.92))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(hovered ? 0.25 : 0.14), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(hovered ? 0.4 : 0.22), radius: hovered ? 8 : 4, y: hovered ? 3 : 1)
                .scaleEffect(hovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover in
            hovered = hover
            if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: hovered)
    }
}

private struct DockTile: View {
    let option: LaunchOption
    let number: Int
    let selected: Bool
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            iconStack

            VStack(alignment: .leading, spacing: 1) {
                Text(option.browser.name)
                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let profile = option.profile {
                    HStack(spacing: 4) {
                        if let hex = option.colorHex, let color = Color(hexString: hex) {
                            Capsule()
                                .fill(color)
                                .frame(width: 8, height: 2.5)
                        }
                        Text(profile.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: 120, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(tileFill)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tileStroke, lineWidth: selected ? 1.2 : 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(
            color: selected ? Color.accentColor.opacity(0.28) : Color.black.opacity(hovered ? 0.18 : 0),
            radius: selected ? 8 : 4,
            x: 0,
            y: selected ? 3 : 2
        )
        .contentShape(Rectangle())
        .scaleEffect(hovered ? 1.03 : 1.0)
        .onHover { isHovered in
            hovered = isHovered
            if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
        .animation(.easeOut(duration: 0.14), value: selected)
        .help("Open in \(option.displayName) (\(number))")
    }

    private var iconStack: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: option.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)

            if number <= 9 {
                Text("\(number)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(width: 13, height: 13)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                    )
                    .offset(x: 4, y: -3)
            }
        }
        .frame(width: 32, height: 28)
    }

    @ViewBuilder
    private var tileFill: some View {
        if selected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if hovered {
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var tileStroke: Color {
        if selected { return Color.accentColor.opacity(0.8) }
        if hovered { return Color.white.opacity(0.22) }
        return Color.white.opacity(0.08)
    }
}

private struct WebContainer: NSViewRepresentable {
    let url: URL
    @Binding var title: String?
    @Binding var isLoading: Bool
    @Binding var progress: Double

    private static let scrollbarCSS: String = """
    ::-webkit-scrollbar { width: 10px; height: 10px; background: transparent; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.18);
        border-radius: 999px;
        border: 2px solid transparent;
        background-clip: padding-box;
        transition: background 0.15s ease;
    }
    ::-webkit-scrollbar-thumb:hover {
        background: rgba(255, 255, 255, 0.32);
        background-clip: padding-box;
        border: 2px solid transparent;
    }
    ::-webkit-scrollbar-corner { background: transparent; }
    html { scrollbar-color: rgba(255,255,255,0.18) transparent; scrollbar-width: thin; }
    """

    private static let scrollbarScript: String = {
        let css = scrollbarCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: " ")
        return """
        (function() {
            var style = document.createElement('style');
            style.setAttribute('data-junction-scrollbar', '1');
            style.textContent = `\(css)`;
            (document.head || document.documentElement).appendChild(style);
        })();
        """
    }()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let userScript = WKUserScript(
            source: Self.scrollbarScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.scrollbarScript = Self.scrollbarScript
        context.coordinator.observe(webView: webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate(webView: nsView)
        nsView.stopLoading()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(title: $title, isLoading: $isLoading, progress: $progress)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var title: String?
        @Binding var isLoading: Bool
        @Binding var progress: Double
        var scrollbarScript: String?
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?

        init(title: Binding<String?>, isLoading: Binding<Bool>, progress: Binding<Double>) {
            _title = title
            _isLoading = isLoading
            _progress = progress
        }

        func observe(webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                guard let value = change.newValue else { return }
                DispatchQueue.main.async { self?.progress = value }
            }
            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, change in
                let value = change.newValue ?? nil
                DispatchQueue.main.async { self?.title = value }
            }
            loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] _, change in
                guard let value = change.newValue else { return }
                DispatchQueue.main.async { self?.isLoading = value }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let script = scrollbarScript else { return }
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func invalidate(webView: WKWebView) {
            progressObservation?.invalidate()
            titleObservation?.invalidate()
            loadingObservation?.invalidate()
            progressObservation = nil
            titleObservation = nil
            loadingObservation = nil
        }
    }
}
