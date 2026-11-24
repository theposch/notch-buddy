import SwiftUI
import WebKit

/// Clawd, drawn by our own clawd.html page in a see-through web view.
struct ClawdView: NSViewRepresentable {
    let mode: String
    let onWord: (String) -> Void

    func makeNSView(context: Context) -> ClawdWebView { ClawdWebView() }

    func updateNSView(_ view: ClawdWebView, context: Context) {
        view.onWord = onWord
        view.show(mode)
    }
}

final class ClawdWebView: WKWebView, WKNavigationDelegate {
    static let color = "#D97757"
    var onWord: ((String) -> Void)?
    private var mode = "life"
    private var loaded = false

    init() {
        let config = WKWebViewConfiguration()
        let messages = ClawdMessages()
        config.userContentController.add(messages, name: "clawd")
        super.init(frame: .zero, configuration: config)
        messages.view = self
        setValue(false, forKey: "drawsBackground")   // let the black notch show through
        navigationDelegate = self
        if let page = Bundle.main.url(forResource: "clawd", withExtension: "html") {
            loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// working, waiting, done, life, …
    func show(_ newMode: String) {
        guard newMode != mode else { return }
        mode = newMode
        if loaded { evaluateJavaScript("setMode('\(mode)')") }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        evaluateJavaScript("setColor('\(Self.color)'); setMode('\(mode)');")
    }

    // Clawd is just a picture: mouse clicks go to the notch behind him.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Hears Clawd's page say what he's doing ({word, mode, anim}).
/// Kept separate so the page doesn't keep the web view alive forever.
final class ClawdMessages: NSObject, WKScriptMessageHandler {
    weak var view: ClawdWebView?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let word = body["word"] as? String else { return }
        view?.onWord?(word)
    }
}
