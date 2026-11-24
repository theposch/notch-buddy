import SwiftUI
import WebKit

/// Clawd, drawn by our own clawd.html page in a see-through web view.
struct ClawdView: NSViewRepresentable {
    func makeNSView(context: Context) -> ClawdWebView { ClawdWebView() }
    func updateNSView(_ view: ClawdWebView, context: Context) {}
}

final class ClawdWebView: WKWebView, WKNavigationDelegate {
    static let color = "#D97757"

    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        setValue(false, forKey: "drawsBackground")   // let the black notch show through
        navigationDelegate = self
        if let page = Bundle.main.url(forResource: "clawd", withExtension: "html") {
            loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Nothing is running yet, so Clawd enjoys his day off.
        evaluateJavaScript("setColor('\(Self.color)'); setMode('life');")
    }

    // Clawd is just a picture: mouse clicks go to the notch behind him.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
