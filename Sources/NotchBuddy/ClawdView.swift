import SwiftUI
import WebKit

/// Clawd, drawn by our own clawd.html page in a see-through web view.
struct ClawdView: NSViewRepresentable {
    let mode: String
    var color = Prefs.clay
    var onWord: ((String) -> Void)?

    func makeNSView(context: Context) -> ClawdWebView { ClawdWebView() }

    func updateNSView(_ view: ClawdWebView, context: Context) {
        view.onWord = onWord
        view.show(mode, color: color)
    }

    /// A row went away: stop its Clawd so the page doesn't keep running.
    static func dismantleNSView(_ view: ClawdWebView, coordinator: ()) {
        view.stopLoading()
        view.configuration.userContentController.removeAllScriptMessageHandlers()
        view.loadHTMLString("", baseURL: nil)
    }
}

final class ClawdWebView: WKWebView, WKNavigationDelegate {
    var onWord: ((String) -> Void)?
    private var mode = "life"
    private var color = Prefs.clay
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

    /// mode: working, waiting, done, life, …  color: "#D97757"
    func show(_ newMode: String, color newColor: String) {
        guard newMode != mode || newColor != color else { return }
        mode = newMode
        color = newColor
        if loaded { tellPage() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !loaded else { return }
        loaded = true
        tellPage()
    }

    private func tellPage() {
        evaluateJavaScript("setColor('\(color)'); setMode('\(mode)');")
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
