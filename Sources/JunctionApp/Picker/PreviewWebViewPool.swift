import AppKit
import WebKit

final class PreviewWebViewPool {
    static let shared = PreviewWebViewPool()

    private let dataStore: WKWebsiteDataStore = .nonPersistent()
    private var cachedWebView: WKWebView?
    private static let blankURL = URL(string: "about:blank")!

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
            if (document.querySelector('style[data-junction-scrollbar]')) return;
            var style = document.createElement('style');
            style.setAttribute('data-junction-scrollbar', '1');
            style.textContent = `\(css)`;
            (document.head || document.documentElement).appendChild(style);
        })();
        """
    }()

    private init() {}

    func warmup() {
        let webView = acquireWebView()
        if webView.url == nil {
            webView.load(URLRequest(url: Self.blankURL))
        }
    }

    func acquireWebView() -> WKWebView {
        if let cached = cachedWebView { return cached }
        let webView = makeWebView()
        cachedWebView = webView
        return webView
    }

    func release(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.load(URLRequest(url: Self.blankURL))
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let userScript = WKUserScript(
            source: Self.scrollbarScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
}
