import AppKit
import WebKit

enum PreviewWebViewFactory {
    private static let dataStore: WKWebsiteDataStore = .nonPersistent()
    private static let blankURL = URL(string: "about:blank")!

    static var readabilitySourceProvider: () -> String? = {
        Bundle.main.url(forResource: "Readability", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private static let readerWrapperScript: String = """
    (function() {
        try {
            var article = new Readability(document.cloneNode(true)).parse();
            if (article && article.content) {
                document.body.innerHTML = article.content;
                if (article.title) { document.title = article.title; }
            }
        } catch(e) {}
    })();
    """

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

    static func userScripts(readerEnabled: Bool) -> [WKUserScript] {
        var scripts: [WKUserScript] = [
            WKUserScript(source: scrollbarScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ]
        if readerEnabled, let source = readabilitySourceProvider() {
            scripts.append(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            scripts.append(WKUserScript(source: readerWrapperScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        return scripts
    }

    static func makeWebView(readerEnabled: Bool = false) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        for script in userScripts(readerEnabled: readerEnabled) {
            config.userContentController.addUserScript(script)
        }

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
