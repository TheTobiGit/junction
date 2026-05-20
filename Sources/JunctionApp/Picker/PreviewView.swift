import SwiftUI
import WebKit
import AppKit

struct PreviewView: View {
    @ObservedObject var model: PickerViewModel
    @ObservedObject private var appSettings = SettingsStore.shared
    @State private var readerEnabled: Bool = false

    var idnRiskFlags: [RiskFlag] { model.riskFlags.filter { $0.isIDNRelated } }

    var body: some View {
        VStack(spacing: 0) {
            webArea
            Divider().opacity(0.12)
            bottomChrome
        }
        .background(
            JunctionChromeBackground(
                theme: appSettings.settings.chromeTheme,
                accent: appSettings.settings.accentPreset.swiftUIColor
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                url: model.previewURL,
                readerEnabled: readerEnabled,
                title: $model.previewTitle,
                isLoading: $model.previewLoading,
                progress: $model.previewProgress
            )
            .id(readerEnabled)
            .background(Color.black.opacity(0.25))

            VStack(spacing: 0) {
                loadingBar
                HStack(alignment: .top) {
                    backButton
                    Spacer(minLength: 0)
                    readerToggleButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
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
        .frame(height: 3)
        .opacity(model.previewLoading || model.previewProgress < 1.0 ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: model.previewLoading)
    }

    private var backButton: some View {
        FloatingIconButton(
            systemName: "chevron.left",
            help: "Back to picker (␣ or ⎋)"
        ) {
            model.exitPreview()
        }
    }

    private var readerToggleButton: some View {
        FloatingIconButton(
            systemName: readerEnabled ? "doc.plaintext.fill" : "doc.plaintext",
            help: readerEnabled ? "Exit reader mode" : "Enter reader mode"
        ) {
            readerEnabled.toggle()
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
        HStack(alignment: .center, spacing: 12) {
            linkIcon
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(model.previewTitle ?? model.preview?.title ?? model.displayHost)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("·")
                        .foregroundColor(.secondary.opacity(0.6))

                    Text(model.displayURLString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if let description = model.preview?.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 10)

            if !idnRiskFlags.isEmpty {
                RiskChip(flags: idnRiskFlags)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var browserDock: some View {
        let options = model.visibleFlatOptions
        let privateActive = model.incognitoMode || model.optionKeyHeld
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element.id) { idx, option in
                    let supportsIncognito = URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
                    let incognitoUnsupported = privateActive && !supportsIncognito
                    DockTile(
                        option: option,
                        number: idx + 1,
                        selected: idx == model.selectedIndex,
                        dimmed: incognitoUnsupported,
                        showIncognito: privateActive && supportsIncognito
                    )
                    .help(incognitoUnsupported
                          ? "\(option.browser.name) doesn't support private windows — it will open normally."
                          : "Open in \(option.displayName) (\(idx + 1))")
                    .onTapGesture {
                        let flags = NSEvent.modifierFlags
                        let incognito = flags.contains(.option) || model.incognitoMode
                        model.pick(option, incognito: incognito)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private var hintBar: some View {
        HStack(spacing: 12) {
            if let host = model.rememberHost, !model.incognitoMode {
                RememberHostToggle(host: host, isOn: model.rememberChoice, action: model.toggleRemember)
            }

            Spacer(minLength: 0)

            if model.previewLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 14, height: 14)
                    Text("Loading")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            HintPill(key: "␣", label: "Back")
            HintPill(key: "↵", label: "Open")
            HintPill(key: "⌥", label: "Private")
            HintPill(key: "1-9", label: "Switch")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .help(PickerShortcutHelp.preview)
    }

    @ViewBuilder
    private var linkIcon: some View {
        FaviconView(data: model.displayFaviconData, fallbackSize: 9)
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
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary.opacity(0.92))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(hovered ? 0.25 : 0.14), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(hovered ? 0.4 : 0.22), radius: hovered ? 10 : 5, y: hovered ? 4 : 2)
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
    let dimmed: Bool
    let showIncognito: Bool
    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            iconStack

            VStack(alignment: .leading, spacing: 2) {
                Text(option.browser.name)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let profile = option.profile {
                    HStack(spacing: 5) {
                        if let hex = option.colorHex, let color = Color(hexString: hex) {
                            Capsule()
                                .fill(color)
                                .frame(width: 10, height: 3)
                        }
                        Text(profile.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: 150, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(tileFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tileStroke, lineWidth: selected ? 1.4 : 0.7)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(
            color: selected ? Color.accentColor.opacity(0.28) : Color.black.opacity(hovered ? 0.18 : 0),
            radius: selected ? 10 : 5,
            x: 0,
            y: selected ? 3 : 2
        )
        .opacity(dimmed ? 0.45 : 1.0)
        .contentShape(Rectangle())
        .scaleEffect(hovered ? 1.03 : 1.0)
        .onHover { isHovered in
            hovered = isHovered
            if isHovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: hovered)
        .animation(.easeOut(duration: 0.14), value: selected)
    }

    private var iconStack: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: option.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .overlay(alignment: .bottomTrailing) {
                    if showIncognito {
                        IncognitoBadge(size: 15)
                            .offset(x: 3, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            if number <= 9 {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                    )
                    .offset(x: 5, y: -4)
            }
        }
        .frame(width: 40, height: 36)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: showIncognito)
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
    let readerEnabled: Bool
    @Binding var title: String?
    @Binding var isLoading: Bool
    @Binding var progress: Double

    func makeNSView(context: Context) -> WKWebView {
        let webView = PreviewWebViewFactory.makeWebView(readerEnabled: readerEnabled)
        webView.navigationDelegate = context.coordinator
        context.coordinator.observe(webView: webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate(webView: nsView)
        PreviewWebViewFactory.teardown(nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(title: $title, isLoading: $isLoading, progress: $progress)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var title: String?
        @Binding var isLoading: Bool
        @Binding var progress: Double
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?

        init(title: Binding<String?>, isLoading: Binding<Bool>, progress: Binding<Double>) {
            _title = title
            _isLoading = isLoading
            _progress = progress
        }

        func observe(webView: WKWebView) {
            invalidate(webView: webView)
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
