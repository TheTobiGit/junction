import AppKit
import WebKit

enum PreviewWebViewFactory {
    private static let dataStore: WKWebsiteDataStore = .nonPersistent()
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

    static func warmup() {
        _ = dataStore
    }

    static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let userScript = WKUserScript(
            source: scrollbarScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = BrowserUserAgent.safariMacDesktop
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    static func teardown(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.load(URLRequest(url: blankURL))
    }
}
