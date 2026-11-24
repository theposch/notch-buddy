import AppKit
import Observation

struct Session: Identifiable {
    enum State { case ready, working, waiting, done }
    let id: String
    var folder: String
    var state: State
    /// When the state last changed.
    var changed = Date()
    /// What it's waiting on: "Run: npm test", "Has a question".
    var summary: String?
    /// True while Allow / Deny from the notch would still reach Claude.
    var canAnswer = false
    /// Its own colour, used when the colour setting is "random".
    var color: String
    var place = Place()

    var clawdMode: String {
        switch state {
        case .ready: "idle"
        case .working: "working"
        case .waiting: "waiting"
        case .done: "done"
        }
    }

    /// Needs you, then working, then done.
    var urgency: Int {
        switch state {
        case .waiting: 3
        case .working: 2
        case .done: 1
        case .ready: 0
        }
    }
}

/// Everything the notch shows. Claude Code events change it; the view follows.
@MainActor @Observable
final class NotchModel {
    var geometry = NotchGeometry()
    var isOpen = false
    private(set) var sessions: [Session] = []
    /// The status word Clawd's page last told us ("Pondering…", "Needs you", …).
    var clawdWord = ""
    private var celebrating = false
    @ObservationIgnored private var celebration: Task<Void, Never>?
    /// Helpers waiting for Allow or Deny, by session.
    @ObservationIgnored private var replies: [String: Reply] = [:]
    /// Off in tests.
    @ObservationIgnored var soundsOn = true

    /// Rows: "needs you" first, then newest.
    var rows: [Session] {
        sessions.sorted {
            ($0.state == .waiting) != ($1.state == .waiting) ? $0.state == .waiting : $0.changed > $1.changed
        }
    }

    /// The session that matters most right now.
    var lead: Session? {
        sessions.max { ($0.urgency, $0.changed) < ($1.urgency, $1.changed) }
    }

    func color(of session: Session) -> String {
        Prefs.clawdColor == Prefs.random ? session.color : Prefs.clawdColor
    }

    // MARK: What Clawd and the wings show

    var clawdMode: String {
        if sessions.contains(where: { $0.state == .waiting }) { return "waiting" }
        if sessions.contains(where: { $0.state == .working }) { return "working" }
        return celebrating ? "done" : "life"
    }

    var clawdColor: String {
        lead.map(color(of:)) ?? (Prefs.clawdColor == Prefs.random ? Prefs.clay : Prefs.clawdColor)
    }

    /// Right wing: Clawd's word while working, otherwise how many sessions are busy.
    var rightText: String? {
        if clawdMode == "working", !clawdWord.isEmpty { return clawdWord }
        let busy = sessions.filter { $0.state == .working || $0.state == .waiting }.count
        return busy > 0 ? "\(busy)" : nil
    }

    static let wingFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    /// Both wings get the same width, so the notch stays centred on the camera.
    var wingWidth: CGFloat {
        guard let text = rightText else { return NotchGeometry.wing }
        let width = (text as NSString).size(withAttributes: [.font: Self.wingFont]).width
        return max(NotchGeometry.wing, ceil(width) + 20)
    }

    var closedSize: CGSize {
        CGSize(width: geometry.cameraWidth + wingWidth * 2, height: geometry.barHeight)
    }

    static let rowHeight: CGFloat = 48
    static let maxRows = 8

    var openSize: CGSize {
        let rows = min(sessions.count, Self.maxRows)
        let body = rows == 0 ? 108 : CGFloat(rows) * Self.rowHeight + 16
        return CGSize(width: NotchGeometry.openSize.width, height: geometry.barHeight + body)
    }

    // MARK: Claude Code events

    /// One event from the helper. `reply` is set when the helper waits for Allow or Deny.
    func handle(_ data: Data, reply: Reply? = nil) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = event["session_id"] as? String,
              let name = event["hook_event_name"] as? String else { reply?.cancel(); return }
        let folder = (event["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Claude"
        let tool = event["tool_name"] as? String

        // Anything that happens next means an open request was answered elsewhere.
        // (A Notification is just Claude reminding you, so it doesn't count.)
        if name != "Notification" { dropReply(for: id) }

        if name == "SessionEnd" {
            sessions.removeAll { $0.id == id }
            return
        }
        let current = sessions.first { $0.id == id }
        var next: Session.State
        var summary: String?
        switch name {
        case "SessionStart":
            next = current?.state ?? .ready
        case "UserPromptSubmit", "PostToolUse":
            next = .working
        case "PreToolUse":
            next = tool == Permission.questionTool ? .waiting : .working
            summary = tool == Permission.questionTool ? "Has a question" : nil
        case "PermissionRequest":
            next = .waiting
            summary = Permission.summary(tool: tool ?? "", input: event["tool_input"] as? [String: Any] ?? [:])
        case "Notification":
            // "Waiting for your input" after a finished turn: done already says that.
            let idle = (event["notification_type"] as? String) == "idle_prompt"
                || ((event["message"] as? String) ?? "").contains("waiting for your input")
            next = idle && (current?.state == .done || current?.state == .ready) ? current!.state : .waiting
            summary = current?.summary
        case "Stop":
            next = .done
        default:
            reply?.cancel()
            return
        }

        var session = current ?? Session(id: id, folder: folder, state: .ready,
                                          color: Prefs.pickColor(avoiding: sessions.map(\.color)))
        let was = current?.state
        session.folder = folder
        session.place = Place(event: event)
        if next != session.state { session.changed = Date() }
        session.state = next
        session.summary = next == .waiting ? summary : nil
        if let reply { replies[id] = reply }
        session.canAnswer = replies[id] != nil

        if next == .waiting, was != .waiting, soundsOn, Prefs.soundNeedsYou { Prefs.play("Ping") }
        if next == .done, was != .done {
            celebrate()
            if soundsOn, Prefs.soundFinished { Prefs.play("Glass") }
            if Prefs.hideFinished { sessions.removeAll { $0.id == id }; return }
        }
        if let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i] = session }
        else { sessions.append(session) }
    }

    /// Allow or Deny, clicked in the notch.
    func answer(_ session: Session, allow: Bool) {
        guard let reply = replies.removeValue(forKey: session.id),
              let i = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        reply.send(allow ? "allow" : "deny")
        sessions[i].state = .working
        sessions[i].summary = nil
        sessions[i].canAnswer = false
        sessions[i].changed = Date()
    }

    /// The helper hung up: Claude was answered somewhere else, or it stopped waiting.
    func replyGone(_ reply: Reply) {
        guard let id = replies.first(where: { $0.value === reply })?.key else { return }
        replies[id] = nil
        if let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i].canAnswer = false }
    }

    private func dropReply(for id: String) {
        replies.removeValue(forKey: id)?.cancel()
        if let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i].canAnswer = false }
    }

    /// Clicking a row: go to its conversation. A finished row is cleared too.
    func open(_ session: Session) {
        session.place.go()
        if session.state == .done { sessions.removeAll { $0.id == session.id } }
    }

    /// Clawd's short "done" dance before he goes back to his day off.
    private func celebrate() {
        celebration?.cancel()
        celebrating = true
        celebration = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.celebrating = false
        }
    }
}
