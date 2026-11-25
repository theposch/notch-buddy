import SwiftUI
import WebKit

/// Clawd, drawn by our own clawd.html page in a see-through web view.
struct ClawdView: NSViewRepresentable {
    let mode: String
    var color = Prefs.clay
    var onWord: ((String) -> Void)?
    /// Copy another Clawd's hobby instead of picking one ("fish", "guitar", …).
    var follow: String? = nil
    /// Hears which hobby he picked while nothing is running.
    var onHobby: ((String) -> Void)? = nil
    /// What Claude is doing; when it changes, a working Clawd moves on to a new animation.
    var step: String? = nil
    /// Something just happened (tests, a merge, …): play its animation once.
    var reaction: Notice? = nil

    func makeNSView(context: Context) -> ClawdWebView { ClawdWebView() }

    func updateNSView(_ view: ClawdWebView, context: Context) {
        view.onWord = onWord
        view.onHobby = onHobby
        view.show(mode, color: color, follow: follow)
        view.moveOn(at: step)
        view.react(to: reaction)
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
    var onHobby: ((String) -> Void)?
    private var mode = "life"
    private var color = Prefs.clay
    private var follow: String?
    private var outfit: String?
    private var step: String?
    private var reacted: UUID?
    /// A reaction that came in before the page finished loading.
    private var waiting: String?
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

    /// mode: working, waiting, done, life, …  color: "#D97757"  follow: another Clawd's hobby
    func show(_ newMode: String, color newColor: String, follow newFollow: String?) {
        let newOutfit = Outfit.today()
        guard newMode != mode || newColor != color || newFollow != follow || newOutfit != outfit else { return }
        mode = newMode
        color = newColor
        follow = newFollow
        outfit = newOutfit
        if loaded { tellPage() }
    }

    /// Claude started its next step: time for a new working animation (the page decides if it's too soon).
    func moveOn(at newStep: String?) {
        guard newStep != step else { return }
        step = newStep
        if loaded, newStep != nil { evaluateJavaScript("nextStep()") }
    }

    /// Plays a reaction once; the page then goes back to what fits the mode.
    /// A Clawd that's still loading (the notch just peeked open) plays it once he's ready.
    func react(to notice: Notice?) {
        guard let notice, let animation = notice.animation, notice.id != reacted else { return }
        reacted = notice.id
        waiting = animation
        if loaded { playWaiting() }
    }

    private func playWaiting() {
        guard let animation = waiting else { return }
        waiting = nil
        evaluateJavaScript("celebrate('\(animation)')")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !loaded else { return }
        loaded = true
        tellPage()
        playWaiting()
    }

    private func tellPage() {
        // Follow first, so a new mode starts on the followed hobby.
        evaluateJavaScript("setColor('\(color)'); setOutfit('\(outfit ?? "")'); setAnim('\(follow ?? "")'); setMode('\(mode)');")
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
        if let mode = body["mode"] as? String, DayPart.restingModes.contains(mode), let anim = body["anim"] as? String {
            view?.onHobby?(anim)
        }
    }
}

/// Clawd dresses up for the season: a Santa hat in December, a party hat for New Year,
/// a witch's hat the week before Halloween.
enum Outfit {
    static func today(_ date: Date = Date(), calendar: Calendar = .current) -> String? {
        // A hidden preference to see one any time: defaults write local.notchbuddy outfit santa
        if let preview = UserDefaults.standard.string(forKey: "outfit") { return preview.isEmpty ? nil : preview }
        let (month, day) = (calendar.component(.month, from: date), calendar.component(.day, from: date))
        switch (month, day) {
        case (12, 31), (1, 1): return "party"
        case (12, _): return "santa"
        case (10, 24...31): return "witch"
        default: return nil
        }
    }
}
