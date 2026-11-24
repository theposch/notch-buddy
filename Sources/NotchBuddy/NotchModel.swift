import AppKit
import Observation
import SwiftUI

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
    /// Usage left in the 5-hour window, from Claude's status line.
    private(set) var usage = Usage.load()
    /// When we last heard from Claude Code at all.
    private(set) var lastHeard: Date?
    /// First launch: the notch shows a welcome instead of rows.
    var welcome = false
    /// A newer version on the downloads page, if there is one.
    var update: Updater.Release?
    /// Goes up whenever a setting changes, so everything that reads one redraws.
    private var prefs = 0
    /// Auto mode fades between the status word and usage left.
    private var autoShowsUsage = false
    private var celebrating = false
    @ObservationIgnored private var celebration: Task<Void, Never>?
    @ObservationIgnored private var exampleRun: Task<Void, Never>?
    @ObservationIgnored private var timers: [Any] = []
    /// Helpers waiting for Allow or Deny, by session.
    @ObservationIgnored private var replies: [String: Reply] = [:]
    /// Off in tests.
    @ObservationIgnored var soundsOn = true

    init() {
        timers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.prefs += 1 }
        })
        timers.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.4)) { self.autoShowsUsage.toggle() }
            }
        })
    }

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
        _ = prefs
        return Prefs.clawdColor == Prefs.random ? session.color : Prefs.clawdColor
    }

    var busyCount: Int { sessions.filter { $0.state == .working || $0.state == .waiting }.count }

    var usageLeft: Int? { usage?.left() }

    // MARK: What Clawd and the wings show

    var clawdMode: String {
        if sessions.contains(where: { $0.state == .waiting }) { return "waiting" }
        if sessions.contains(where: { $0.state == .working }) { return "working" }
        return celebrating ? "done" : "life"
    }

    var clawdColor: String {
        _ = prefs
        return lead.map(color(of:)) ?? (Prefs.clawdColor == Prefs.random ? Prefs.clay : Prefs.clawdColor)
    }

    var rightSide: Prefs.RightSide { _ = prefs; return Prefs.rightSide }

    /// The right wing, following the "right side" setting.
    var rightText: String? {
        let word = clawdWord.isEmpty ? nil : clawdWord
        let usageText = usageLeft.map { "\($0)%" }
        switch rightSide {
        case .word: return word
        case .sessions: return busyCount > 0 ? "\(busyCount)" : nil
        case .usage: return usageText
        case .auto:
            if clawdMode == "waiting" { return "Needs you" }
            guard let word else { return usageText }
            let counted = busyCount > 1 ? "\(word) · \(busyCount)" : word
            return autoShowsUsage ? usageText ?? counted : counted
        }
    }

    /// True when the right wing is showing usage left (it's coloured by how much is left).
    var rightIsUsage: Bool { rightText != nil && rightText == usageLeft.map { "\($0)%" } }

    /// The "Sessions" option spins while any session is working.
    var showsSpinner: Bool { rightSide == .sessions && sessions.contains { $0.state == .working } }

    static let wingFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    /// Both wings get the same width, so the notch stays centred on the camera.
    var wingWidth: CGFloat {
        guard let text = rightText else { return NotchGeometry.wing }
        let width = (text as NSString).size(withAttributes: [.font: Self.wingFont]).width
        return max(NotchGeometry.wing, ceil(width) + 20 + (showsSpinner ? 18 : 0))
    }

    var closedSize: CGSize {
        CGSize(width: geometry.cameraWidth + wingWidth * 2, height: geometry.barHeight)
    }

    static let rowHeight: CGFloat = 48
    static let headerHeight: CGFloat = 30
    static let maxRows = 8

    var openSize: CGSize {
        let rows = min(sessions.count, Self.maxRows)
        let body = welcome ? 128 : Self.headerHeight + (rows == 0 ? 80 : CGFloat(rows) * Self.rowHeight + 10)
        return CGSize(width: NotchGeometry.openSize.width, height: geometry.barHeight + body)
    }

    // MARK: Claude Code events

    /// One event from the helper. `reply` is set when the helper waits for Allow or Deny.
    func handle(_ data: Data, reply: Reply? = nil) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = event["hook_event_name"] as? String else { reply?.cancel(); return }
        lastHeard = Date()
        if name == Usage.event, let used = event["used_percentage"] as? Double,
           let resets = event["resets_at"] as? Double {
            usage = Usage(used: used, resets: Date(timeIntervalSince1970: resets))
            usage?.save()
            return
        }
        guard let id = event["session_id"] as? String, id != Self.exampleID else { reply?.cancel(); return }
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
        store(session, was: was)
    }

    /// Saves a session's new state, with the sound and celebration that go with it.
    private func store(_ session: Session, was: Session.State?) {
        if session.state == .waiting, was != .waiting, soundsOn, Prefs.soundNeedsYou { Prefs.play("Ping") }
        if session.state == .done, was != .done {
            celebrate()
            if soundsOn, Prefs.soundFinished { Prefs.play("Glass") }
            if Prefs.hideFinished { sessions.removeAll { $0.id == session.id }; return }
        }
        if let i = sessions.firstIndex(where: { $0.id == session.id }) { sessions[i] = session }
        else { sessions.append(session) }
    }

    // MARK: The example

    static let exampleID = "notch-buddy-example"

    /// A pretend session that works, needs you, then finishes (about 6 seconds),
    /// so a changed setting shows in the real notch. Real sessions are never touched.
    func playExample() {
        exampleRun?.cancel()
        exampleRun = Task { [weak self] in
            let steps: [(Session.State, String?)] = [(.working, nil), (.waiting, "Run: npm test"), (.done, nil)]
            for (state, summary) in steps {
                self?.showExample(state, summary: summary)
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
            }
            withAnimation { self?.sessions.removeAll { $0.id == Self.exampleID } }
        }
    }

    private func showExample(_ state: Session.State, summary: String?) {
        let current = sessions.first { $0.id == Self.exampleID }
        var example = current ?? Session(id: Self.exampleID, folder: "Example", state: .ready,
                                         color: Prefs.pickColor(avoiding: sessions.map(\.color)))
        example.state = state
        example.summary = summary
        example.changed = Date()
        withAnimation(.spring(duration: 0.32, bounce: 0.18)) { store(example, was: current?.state) }
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
        guard session.id != Self.exampleID else { return }
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
