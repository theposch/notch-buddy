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
    /// When its current job started; kept while it waits for you, cleared when it's done.
    var workingSince: Date?
    /// What it's waiting on: "Run: npm test", "Has a question".
    var summary: String?
    /// The whole command, path or address, shown on hover.
    var detail: String?
    /// The rule "Always allow" would add ("Bash(npm test:*)"), when Claude suggests one.
    var always: String?
    /// When we last heard from it.
    var heard = Date()
    /// What it's doing right now ("Editing NotchView.swift"), while it works.
    var activity: String?
    /// The name you gave the conversation ("app build"), when it has one.
    var title: String?
    /// The title, or else the folder it works in.
    var name: String { title ?? folder }
    /// Its model, short: "Opus 5.5".
    var model: String?
    /// The organization it runs on, when the desktop app says (Terminal sessions are on the Terminal login's).
    var org: String?
    /// The git branch its folder is on: "main".
    var branch: String?
    /// Lines changed, tests, servers, to-dos and helpers.
    var work = Work()
    /// Its branch's pull request, when it has one.
    var pr: PullRequest?
    /// What it has cost so far, when Claude's status line says (in Terminal).
    var cost: Double?
    /// Something that just happened, shown on the row for a few seconds: "Fixed it! Tests pass again".
    var notice: Notice?
    /// Why its last turn failed, when Claude ran into an error: "Hit the rate limit".
    var problem: String?
    /// Waiting on you to review a plan, not to allow a single step.
    var plan = false
    /// How full its conversation is, 0–100.
    var context: Int?
    /// True once Claude's status line has said; it's exact, so it wins over our own reading.
    var contextFromStatusLine = false
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

    /// Lines shown under a "needs you" row while the mouse is over it: the whole command,
    /// and what "Always allow" would allow. Long lines wrap, up to 6 of them.
    var hoverLines: Int {
        guard state == .waiting, let detail else { return 0 }
        let wrapped = detail.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { $0 + max(1, ($1.count + 63) / 64) }
        return min(wrapped, 6) + (always != nil && canAnswer ? 1 : 0)
    }

    static let hoverLineHeight: CGFloat = 15

    /// The details line that slides in while the mouse is over the row.
    /// `shortcut`: this row is the one ⌥⌘Y and ⌥⌘N answer.
    func details(shortcut: Bool) -> [Detail] {
        var list: [Detail] = []
        if shortcut { list.append(.keys) }
        if let branch { list.append(.branch(branch)) }
        if let text = work.linesText { list.append(.lines(text)) }
        if let tests = work.tests { list.append(.tests(tests)) }
        if let pr { list.append(.pullRequest(pr)) }
        if let server = work.server { list.append(.server(server)) }
        if let todos = work.todos { list.append(.todo("\(todos.done) of \(todos.total)" + (todos.current.map { " · \($0)" } ?? ""))) }
        if let cost { list.append(.cost(cost)) }
        return list
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

/// Nothing running: Clawd lives his best life. His hobbies go all day; mornings start with
/// One piece of a row's details line.
enum Detail: Hashable {
    case keys, branch(String), lines(String), tests(Work.Tests), pullRequest(PullRequest), server(URL), todo(String), cost(Double)

    var text: String {
        switch self {
        case .keys: "\(Shortcuts.allowText) allow · \(Shortcuts.denyText) deny"
        case .branch(let name): name
        case .lines(let text): text
        case .tests(let tests): tests.text
        case .pullRequest(let pr): pr.text
        case .server(let url): (url.host() ?? "localhost") + (url.port.map { ":\($0)" } ?? "")
        case .todo(let text): text
        case .cost(let dollars): String(format: "$%.2f", dollars)
        }
    }

    /// Most pieces start with a small symbol.
    var hasSymbol: Bool {
        switch self {
        case .keys, .lines, .cost: false
        default: true
        }
    }
}

/// coffee and late nights with a nightcap, which keep coming back now and then.
enum DayPart {
    case morning, day, night

    init(hour: Int) {
        self = (5..<10).contains(hour) ? .morning : (hour >= 23 || hour < 5) ? .night : .day
    }

    static var now: DayPart { DayPart(hour: Calendar.current.component(.hour, from: Date())) }

    /// Clawd's page modes for these.
    static let restingModes: Set<String> = ["life", "morning", "night"]

    /// Clawd's mode on his page.
    var clawdMode: String {
        switch self {
        case .morning: "morning"
        case .day: "life"
        case .night: "night"
        }
    }

    /// Said when we don't know his hobby yet.
    var line: String {
        switch self {
        case .morning: "Good morning. Coffee first."
        case .day: "Nothing running. Clawd\u{2019}s enjoying his day off."
        case .night: "It\u{2019}s late. Clawd\u{2019}s off to bed."
        }
    }

    /// Like a status in a chat app, one for each thing he does. No emoji: Clawd's picture says it.
    static let status: [String: String] = [
        "coffee": "Coffee first. Then code. Maybe.",
        "nightcap": "Off to bed. Wake me if it compiles.",
        "fish": "Gone fishing. Bugs only bite on Mondays.",
        "read": "Reading the docs. For fun. Yes, really.",
        "guitar": "Jamming. Back in five (songs).",
        "bubbles": "Blowing bubbles. Very important work.",
        "telescope": "Looking for bugs in space.",
        "tea": "Tea break. Steeping, not sleeping.",
        "surf": "Catching waves, not errors.",
        "sax": "Smooth jazz hour. No meetings, please.",
        "paint": "Painting. It\u{2019}s abstract, like the specs.",
        "water": "Watering plants. They grow faster than tests.",
        "balloons": "Party of one. Everything shipped.",
        "lollipop": "Lollygagging, professionally.",
        "gaming": "Gaming. Strictly research.",
        "headphones": "Lo-fi beats to do nothing to.",
        "icecream": "Ice cream break. Earned it.",
        "kite": "Flying a kite. Head in the cloud.",
        "sunbathe": "Out of office. Very out.",
        "skate": "Kickflipping over merge conflicts.",
        "cat": "Petting the cat. The cat says hi.",
        "yawn": "Long day of doing nothing.",
    ]

    /// What the open notch says under "All caught up".
    func line(for hobby: String?) -> String { hobby.flatMap { Self.status[$0] } ?? line }
}

/// Everything the notch shows. Claude Code events change it; the view follows.
@MainActor @Observable
final class NotchModel {
    var geometry = NotchGeometry()
    var isOpen = false
    private(set) var sessions: [Session] = []
    /// The status word Clawd's page last told us ("Pondering…", "Needs you", …).
    var clawdWord = ""
    /// Each Claude account's 5-hour and weekly usage, from the status line or the logins.
    private(set) var accounts = Account.load()
    /// The account Claude Code in the Terminal is logged in to; Terminal sessions are on it.
    var terminalOrg: String?
    /// What got done today, for the empty notch.
    private(set) var today = Today.load()
    /// When we last heard from Claude Code at all.
    private(set) var lastHeard: Date?
    /// Usage from the logins on this Mac (set by the app; tests leave them out).
    @ObservationIgnored var loginChecks: [LoginUsage] = []
    /// A turn just ended: a good moment to look at usage again.
    @ObservationIgnored var onDone: (() -> Void)?
    /// The row the mouse is over; a "needs you" row then shows the whole command.
    var hovered: String?
    /// First launch: the notch shows a welcome instead of rows.
    var welcome = false
    /// A newer version on the downloads page, if there is one.
    var update: Updater.Release?
    /// Goes up whenever a setting changes, so everything that reads one redraws.
    private(set) var prefs = 0
    /// Auto mode fades between the status word and usage left.
    private var autoShowsUsage = false
    private var celebrating = false
    @ObservationIgnored private var celebration: Task<Void, Never>?
    @ObservationIgnored private var exampleRun: Task<Void, Never>?
    @ObservationIgnored private var timers: [Any] = []
    /// Helpers waiting for Allow or Deny, by session.
    @ObservationIgnored private var replies: [String: Reply] = [:]
    /// Off in tests: no sounds, nothing saved for the daily recap, no pull request lookups.
    @ObservationIgnored var live = true

    init() {
        timers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // macOS can say this in the middle of drawing a view (Settings), when changing
            // what views read isn't allowed. So redraw a moment later instead.
            Task { @MainActor in self?.prefs += 1 }
        })
        timers.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.tidy()
            }
        })
        timers.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.lookUpPullRequests()
            }
        })
        timers.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.4)) { self.autoShowsUsage.toggle() }
                if self.sessions.contains(where: { $0.state == .waiting }) { self.tick = Date() }
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

    // MARK: Usage

    /// Accounts we know usage for, minus the ones you switched off.
    var shownAccounts: [Account] { _ = prefs; return accounts.filter { $0.shown && ($0.usage != nil || $0.week != nil) } }
    var severalAccounts: Bool { shownAccounts.count > 1 }

    func org(of session: Session) -> String { session.org ?? terminalOrg ?? "" }
    func account(of session: Session) -> Account? { accounts.first { $0.id == org(of: session) } }

    /// The account whose usage the closed notch shows (and Clawd sweats about).
    var followed: Account? {
        let list = shownAccounts
        guard list.count > 1 else { return list.first }
        switch Follow.saved {
        case .lowest: return list.min { ($0.left ?? 100) < ($1.left ?? 100) }
        case .account(let id): return list.first { $0.id == id } ?? list.first
        case .lead: return lead.flatMap { account(of: $0) }.flatMap { a in list.first { $0.id == a.id } } ?? list.first
        }
    }

    var usage: Usage? { followed?.usage }
    var week: Usage? { followed?.week }
    var usageLeft: Int? { usage?.left() }
    var weekLeft: Int? { week?.left() }

    /// The request ⌥⌘Y and ⌥⌘N answer: the top one that can be answered from here (not a plan).
    var shortcutTarget: Session? {
        _ = prefs
        return Prefs.shortcuts ? rows.first { $0.state == .waiting && $0.canAnswer && !$0.plan } : nil
    }

    /// Under this much usage left (you choose, standard 10%), Clawd sweats and the notch says so.
    var lowUsage: Int { _ = prefs; return Prefs.limit(.usageLow) }
    var usageIsLow: Bool { usageLeft.map { $0 < lowUsage } ?? false }
    /// All used up: Clawd naps until it resets.
    var usageOut: Bool { usageLeft == 0 }
    var resetTime: String? { usage.map { $0.resets.formatted(date: .omitted, time: .shortened) } }

    /// Called when a session starts needing you, or there's big news, so the notch can peek.
    var onPeek: (() -> Void)?
    /// The message on the closed notch right now, for a few seconds.
    private(set) var shown: Notice?
    /// What the closed notch's Clawd last reacted to (even when its message is switched off).
    private(set) var reaction: Notice?
    /// Messages waiting their turn on the closed notch, and when they came in.
    @ObservationIgnored private var queue: [(notice: Notice, at: Date)] = []
    /// Moves on every few seconds, so "Still waiting · 5m" appears on time.
    private(set) var tick = Date()

    /// While Claude waits on you, the closed notch says what for: "Run npm test?", "Plan ready".
    /// It stays until you answer. Nil when nothing waits, or you've switched that message off.
    var needsLine: String? {
        _ = prefs
        guard let session = rows.first(where: { $0.state == .waiting }) else { return nil }
        let named = sessions.count > 1
        let minutes = Int(tick.timeIntervalSince(session.changed) / 60)
        if Prefs.shows(.stillWaiting), minutes >= Prefs.limit(.stillWaiting) {
            return named ? "\(Notice.short(session.name)) · \(minutes)m" : "Still waiting · \(minutes)m"
        }
        let kind: Notice.Kind = session.plan ? .plan : session.summary == "Has a question" ? .question : .askToRun
        guard Prefs.shows(kind) else { return nil }
        let what: String
        switch kind {
        case .plan: what = "Plan ready"
        case .question: what = named ? "asks" : "Has a question"
        default:
            // "Run: npm test" asks "Run npm test?"; anything else is said as it is.
            let summary = session.summary ?? "Needs you"
            what = Notice.short(summary.contains(": ") ? summary.replacingOccurrences(of: ": ", with: " ") + "?" : summary, to: 22)
        }
        return named ? "\(Notice.short(session.name)): \(what)".replacingOccurrences(of: ": asks", with: " asks") : what
    }

    /// "Back at 7:00 PM" stays on the closed notch while usage is used up, if you want it there.
    var outLine: String? {
        _ = prefs
        guard usageOut, Prefs.shows(.usageOut), let time = resetTime else { return nil }
        return "Back at \(time)"
    }

    // MARK: What Clawd and the wings show

    var clawdMode: String {
        if sessions.contains(where: { $0.state == .waiting }) { return "waiting" }
        if usageOut { return "out" }
        if usageIsLow { return "low" }
        if sessions.contains(where: { $0.state == .working }) { return "working" }
        return celebrating ? "done" : DayPart.now.clawdMode
    }

    /// Clawd's colour while nothing is running. With the random setting, picked once per launch.
    private let restColor = Prefs.pickColor(avoiding: [])
    var restingColor: String { _ = prefs; return Prefs.clawdColor == Prefs.random ? restColor : Prefs.clawdColor }
    /// The hobby the notch's Clawd is doing while nothing runs; the open notch's Clawd copies it.
    var hobby: String?

    var clawdColor: String {
        _ = prefs
        return lead.map(color(of:)) ?? restingColor
    }

    var rightSide: Prefs.RightSide { _ = prefs; return Prefs.rightSide }

    /// The right wing, following the "right side" setting.
    var rightText: String? {
        if let line = needsLine ?? outLine ?? shown?.word { return line }
        let word = clawdWord.isEmpty ? nil : clawdWord
        let usageText = usageLeft.map { "\($0)%" }
        switch rightSide {
        case .word: return word
        case .sessions: return busyCount > 0 ? "\(busyCount)" : nil
        // Usage isn't known until Claude Code in the Terminal sends it; say Clawd's word meanwhile.
        case .usage: return usageText ?? word
        case .auto:
            if clawdMode == "waiting" { return "Needs you" }
            if usageOut, let time = resetTime { return "Back at \(time)" }
            guard let word else { return usageText }
            let counted = busyCount > 1 ? "\(word) · \(busyCount)" : word
            return autoShowsUsage ? usageText ?? counted : counted
        }
    }

    /// True when the right wing is showing usage left (it's coloured by how much is left).
    var rightIsUsage: Bool { rightText != nil && rightText == usageLeft.map { "\($0)%" } }

    /// The "Sessions" option spins while any session is working.
    var showsSpinner: Bool { needsLine == nil && outLine == nil && shown == nil && rightSide == .sessions && sessions.contains { $0.state == .working } }

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
    static let maxRows = 8

    var openSize: CGSize {
        let rows = min(sessions.count, Self.maxRows)
        let width = openWidth
        let row = self.rows.prefix(Self.maxRows).first { $0.id == hovered }
        let lines = (row?.hoverLines ?? 0) + (row.map { Self.detailLines($0.details(shortcut: $0.id == shortcutTarget?.id), width: width - 82) } ?? 0)
        let hover = lines > 0 ? CGFloat(lines) * Session.hoverLineHeight + 8 : 0
        let empty: CGFloat = today.line == nil || usageOut ? 124 : 140
        let body = welcome ? 128 : (rows == 0 ? empty : CGFloat(rows) * Self.rowHeight + 14 + hover)
        return CGSize(width: width, height: geometry.barHeight + body)
    }

    // MARK: The open notch's top strip

    static let topFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    static func topWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: topFont]).width)
    }

    /// How wide the usage at the top of the open notch is. `short` leaves out account names
    /// (or, with one account, the reset time); hovering still shows them.
    func usageStripWidth(short: Bool) -> CGFloat {
        var pieces: [CGFloat] = []
        if severalAccounts {
            for account in shownAccounts {
                guard let left = account.left else { continue }
                pieces.append(6 + 5 + (short ? 0 : Self.topWidth(account.name) + 5) + Self.topWidth("\(left)%") + 6)
            }
        } else {
            if let left = usageLeft { pieces.append(Self.topWidth("\(left)% left")) }
            if !short, let resets = usage?.resets { pieces.append(Self.topWidth("resets \(resets.formatted(date: .omitted, time: .shortened))")) }
            if let week = weekLeft { pieces += [Self.topWidth("· week"), Self.topWidth("\(week)% left")] }
        }
        return pieces.reduce(0, +) + CGFloat(max(0, pieces.count - 1)) * 6
    }

    /// Room for the usage left of the camera on a MacBook (padding and a little air taken off).
    private var roomBesideCamera: CGFloat {
        (max(NotchGeometry.openSize.width, geometry.cameraWidth + 2 * 175) - geometry.cameraWidth) / 2 - 26
    }

    /// On a MacBook the camera sits in the middle of the strip, so when the usage doesn't fit
    /// beside it, it goes short. Other screens have room.
    var shortUsageStrip: Bool { geometry.hasNotch && usageStripWidth(short: false) > roomBesideCamera }

    var openWidth: CGFloat {
        let strip = usageStripWidth(short: shortUsageStrip)
        guard geometry.hasNotch else {
            // Usage, a gap, then Settings and Quit, all in one line.
            return max(NotchGeometry.openWidthWithoutCamera, strip + 36 + 24 + 56)
        }
        // Wide enough that usage left and the buttons fit either side of the camera.
        return max(NotchGeometry.openSize.width, geometry.cameraWidth + 2 * 175, geometry.cameraWidth + 2 * (strip + 26))
    }

    static let detailFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    /// How many lines a details line takes when it wraps at this width.
    static func detailLines(_ details: [Detail], width: CGFloat) -> Int {
        var lines = 0, x: CGFloat = 0
        for detail in details {
            let w = ceil((detail.text as NSString).size(withAttributes: [.font: detailFont]).width) + (detail.hasSymbol ? 15 : 0)
            if lines == 0 || x + w > width { lines += 1; x = 0 }
            x += w + 10
        }
        return lines
    }

    // MARK: Claude Code events

    /// The 5-hour and weekly usage of one account, from the status line or a login.
    /// The account is the one the event names, else its session's, else the Terminal login's.
    func takeUsage(_ event: [String: Any]) {
        let session = (event["session_id"] as? String).flatMap { id in sessions.first { $0.id == id } }
        let id = event[Account.key] as? String ?? session.map(org(of:)) ?? terminalOrg ?? ""
        if id != "" { accounts.removeAll { $0.id == "" } }   // heard before we knew whose it was
        var account = accounts.first { $0.id == id } ?? Account(id: id)
        if account.from == nil, let from = event["from"] as? String { account.from = from }   // first one names it
        var droppedTo: Int?
        if let used = event["used_percentage"] as? Double, let resets = event["resets_at"] as? Double {
            let before = account.left ?? 100
            account.usage = Usage(used: used, resets: Date(timeIntervalSince1970: resets))
            if before >= lowUsage, let left = account.left, left < lowUsage, account.shown { droppedTo = left }
        }
        if let used = event["week_used"] as? Double, let resets = event["week_resets"] as? Double {
            account.week = Usage(used: used, resets: Date(timeIntervalSince1970: resets))
        }
        if let i = accounts.firstIndex(where: { $0.id == id }) { accounts[i] = account } else { accounts.append(account) }
        Account.save(accounts)
        // Just dropped under your limit: one soft sound and a message (Clawd starts sweating by himself).
        if let left = droppedTo {
            if live { Prefs.play(.usageLow) }
            post([Notice(kind: .usageLow, word: severalAccounts ? "\(account.name) \(left)% left" : "\(left)% left")], for: nil)
        }
    }

    /// One event from the helper. `reply` is set when the helper waits for Allow or Deny.
    func handle(_ data: Data, reply: Reply? = nil) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = event["hook_event_name"] as? String else { reply?.cancel(); return }
        lastHeard = Date()
        if name == Usage.event {
            if let used = event["used_percentage"] {
                LoginUsage.log.notice("usage from the status line: \(String(describing: used), privacy: .public)% used")
            }
            takeUsage(event)
            if let id = event["session_id"] as? String, let i = sessions.firstIndex(where: { $0.id == id }) {
                let before = sessions[i]
                defer { post(Notice.spot(before, sessions[i], event: name, named: sessions.count > 1), for: id) }
                if let used = event["context_used"] as? Double {
                    sessions[i].context = min(100, max(0, Int(used.rounded())))
                    sessions[i].contextFromStatusLine = true
                }
                if let cost = event["cost"] as? Double { sessions[i].cost = cost }
            }
            return
        }
        guard let id = event["session_id"] as? String, id != Self.exampleID else { reply?.cancel(); return }
        let folder = (event["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Claude"
        let tool = event["tool_name"] as? String

        // Helpers starting and stopping only change the "+2" on Clawd.
        if name == "SubagentStart" || name == "SubagentStop" {
            if let i = sessions.firstIndex(where: { $0.id == id }) {
                let before = sessions[i]
                sessions[i].work.note(name, tool: "", event: event)
                post(Notice.spot(before, sessions[i], event: name, named: sessions.count > 1), for: id)
            }
            reply?.cancel()
            return
        }

        // Anything that happens next means an open request was answered elsewhere.
        // (A Notification is just Claude reminding you, so it doesn't count.)
        if name != "Notification" { dropReply(for: id) }

        if name == "SessionEnd" {
            // Ended while Claude was still on it: you stopped it.
            if let gone = sessions.first(where: { $0.id == id }), gone.state == .working || gone.state == .waiting {
                let named = sessions.count > 1
                post([Notice(kind: .stopped, word: named ? "\(Notice.short(gone.name)) stopped" : "Stopped")], for: nil)
            }
            sessions.removeAll { $0.id == id }
            showNext()
            return
        }
        let current = sessions.first { $0.id == id }
        var next: Session.State
        var summary: String?
        var detail: String?
        var always: String?
        // Kept between tools (Claude is still on it), cleared by a new message or the end of a turn.
        var activity = ["PostToolUse", "PostToolUseFailure", "PermissionRequest", "Notification", "PreCompact"].contains(name) ? current?.activity : nil
        var plan = name == "Notification" ? current?.plan ?? false : false
        switch name {
        case "SessionStart":
            next = current?.state ?? .ready
        case "UserPromptSubmit", "PostToolUse", "PostToolUseFailure":
            next = .working
        case "PreToolUse":
            next = tool == Permission.questionTool ? .waiting : .working
            summary = tool == Permission.questionTool ? "Has a question" : nil
            plan = tool == "ExitPlanMode"
            if next == .working { activity = Activity.line(tool: tool ?? "", input: event["tool_input"] as? [String: Any] ?? [:]) }
        case "PermissionRequest":
            next = .waiting
            let input = event["tool_input"] as? [String: Any] ?? [:]
            summary = Permission.summary(tool: tool ?? "", input: input)
            detail = Permission.detail(tool: tool ?? "", input: input)
            always = Permission.alwaysText(event)
            plan = tool == "ExitPlanMode"
        case "Notification":
            // "Waiting for your input" after a finished turn: done already says that.
            let idle = (event["notification_type"] as? String) == "idle_prompt"
                || ((event["message"] as? String) ?? "").contains("waiting for your input")
            next = idle && (current?.state == .done || current?.state == .ready) ? current!.state : .waiting
            (summary, detail, always) = (current?.summary, current?.detail, current?.always)
        case "Stop", "StopFailure":
            next = .done
        case "PreCompact":
            // Claude is making room in the conversation; nothing else changes.
            next = current?.state ?? .working
            (summary, detail, always) = (current?.summary, current?.detail, current?.always)
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
        if next == .working || next == .waiting { session.workingSince = session.workingSince ?? Date() }
        else { session.workingSince = nil }
        session.state = next
        session.summary = next == .waiting ? summary : nil
        session.detail = next == .waiting ? detail : nil
        session.always = next == .waiting ? always : nil
        session.activity = activity
        session.plan = next == .waiting && plan
        session.work.note(name, tool: tool ?? "", event: event)
        let branch = event[Git.branchKey] as? String
        let newBranch = branch != nil && branch != session.branch
        if let branch { session.branch = branch }
        if let id = (event[ModelName.key] ?? event["model"]) as? String, let model = ModelName.short(id) { session.model = model }
        if let title = event[ConversationSize.titleKey] as? String { session.title = title }
        if let org = event[Account.key] as? String { session.org = org }
        session.heard = Date()
        if name == "StopFailure" {
            session.problem = Notice.problem(event["error"] as? String ?? event["error_type"] as? String ?? event["reason"] as? String)
        } else if name == "UserPromptSubmit" { session.problem = nil }
        if !session.contextFromStatusLine, let used = event[ConversationSize.key] as? Int { session.context = used }
        if let reply { replies[id] = reply }
        session.canAnswer = replies[id] != nil
        count(session, before: current)
        store(session, was: was)
        var news = Notice.spot(current, session, event: name, named: sessions.count > 1)
        if name == "SessionStart", current == nil, (event["source"] as? String ?? "startup") == "startup" {
            news.append(Notice(kind: .started, word: "New: \(Notice.short(session.name))"))
        }
        post(news, for: id)
        if newBranch { lookUpPullRequests() }
    }

    /// Saves a session's new state, with the sound and celebration that go with it.
    private func store(_ session: Session, was: Session.State?) {
        // Answered: messages that waited behind "needs you" get their turn.
        defer { if was == .waiting, session.state != .waiting { showNext() } }
        if session.state == .waiting, was != .waiting {
            if live { Prefs.play(.needsYou) }
            if session.id != Self.exampleID { onPeek?() }
        }
        if session.state == .done, was != .done {
            onDone?()
            celebrate()
            if live { Prefs.play(.finished) }
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

    enum Answer: String { case allow, always, deny }

    /// Allow, Always allow or Deny, clicked in the notch.
    func answer(_ session: Session, _ answer: Answer) {
        guard let reply = replies.removeValue(forKey: session.id),
              let i = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        reply.send(answer.rawValue)
        sessions[i].state = .working
        sessions[i].summary = nil
        sessions[i].detail = nil
        sessions[i].always = nil
        sessions[i].canAnswer = false
        sessions[i].changed = Date()
        showNext()
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

    // MARK: Tidying up

    /// Removes sessions whose Claude has quit or crashed without saying goodbye, and stops showing
    /// "Working" for one that's been silent for half an hour (stopped with Esc, for example).
    func tidy(now: Date = Date(), isRunning: (Int32) -> Bool = NotchModel.isRunning) {
        // The usage window has reset: we don't know the new figure until Claude says (and Clawd wakes up).
        for i in accounts.indices {
            guard let usage = accounts[i].usage, now >= usage.resets else { continue }
            // A fresh window. Worth saying if it was running low or out.
            if accounts[i].shown, Int((100 - usage.used).rounded()) < lowUsage {
                post([Notice(kind: .usageReset, word: severalAccounts ? "\(accounts[i].name): fresh 5 hours" : "Fresh 5 hours")], for: nil)
            }
            accounts[i].usage = nil
            Account.save(accounts)
        }
        for session in sessions where session.id != Self.exampleID {
            if let pid = session.place.pid, !isRunning(pid) {
                dropReply(for: session.id)
                withAnimation { sessions.removeAll { $0.id == session.id } }
            } else if session.state == .working, now.timeIntervalSince(session.heard) > 30 * 60,
                      let i = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[i].state = .ready
                sessions[i].changed = now
                sessions[i].workingSince = nil
            }
        }
    }

    nonisolated static func isRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// Clicking a row: go to its conversation. A finished row is cleared too.
    func open(_ session: Session) {
        guard session.id != Self.exampleID else { return }
        session.place.go()
        if session.state == .done { sessions.removeAll { $0.id == session.id } }
    }

    /// "Clear from the list" in a row's menu.
    func clear(_ session: Session) {
        dropReply(for: session.id)
        sessions.removeAll { $0.id == session.id }
    }

    /// Adds a session's latest to today's figures.
    private func count(_ session: Session, before: Session?) {
        guard live, session.id != Self.exampleID else { return }
        var t = today.day == Today.dayName() ? today : Today(day: Today.dayName())
        if session.state == .working || session.state == .waiting { t.sessions.insert(session.id) }
        if let since = before?.workingSince, session.workingSince == nil { t.seconds += Date().timeIntervalSince(since) }
        t.added += max(0, session.work.added - (before?.work.added ?? 0))
        t.removed += max(0, session.work.removed - (before?.work.removed ?? 0))
        t.files.formUnion(session.work.files)
        guard t != today else { return }
        today = t
        t.save()
    }

    /// Asks GitHub about each session's branch (needs GitHub's own `gh` tool, signed in).
    func lookUpPullRequests() {
        guard live else { return }
        for folder in Set(sessions.compactMap { $0.branch != nil ? $0.place.folder : nil }) {
            Task { [weak self] in
                let pr = await PullRequest.look(in: folder)
                guard let self else { return }
                var news: (Notice, String)?
                for i in self.sessions.indices where self.sessions[i].place.folder == folder && self.sessions[i].pr != pr {
                    if news == nil, let notice = Notice.spot(self.sessions[i].pr, pr) { news = (notice, self.sessions[i].id) }
                    withAnimation { self.sessions[i].pr = pr }
                }
                if let (notice, id) = news { self.post([notice], for: id) }
            }
        }
    }

    // MARK: Messages

    /// Something happened. The row says it for a few seconds and Clawd reacts; the closed notch
    /// says it too if you've chosen to see that kind, and big news peeks the notch open.
    /// `id` is the session it's about, if any.
    func post(_ notices: [Notice], for id: String?) {
        guard id != Self.exampleID else { return }
        for notice in notices {
            withAnimation(.snappy) {
                if let id, let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i].notice = notice }
                if Prefs.celebrations, notice.animation != nil { reaction = notice }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Notice.seconds))
                guard let self else { return }
                withAnimation(.snappy) {
                    for i in self.sessions.indices where self.sessions[i].notice?.id == notice.id { self.sessions[i].notice = nil }
                }
            }
            guard Prefs.shows(notice.kind) else { continue }
            // Peek only if there's a row to see (a finished session may already be hidden).
            if notice.opensNotch, id == nil || sessions.contains(where: { $0.id == id }) { onPeek?() }
            say(notice)
        }
    }

    /// Puts a message on the closed notch, or in line for it. Something more important takes over
    /// right away (the one it covers goes back in line); the rest wait their turn. "Needs you" always comes first.
    private func say(_ notice: Notice) {
        if shown?.kind == notice.kind || queue.contains(where: { $0.notice.kind == notice.kind }) { return }
        guard needsLine == nil, shown.map({ notice.rank > $0.rank }) ?? true else {
            queue.append((notice, Date()))
            return
        }
        if let covered = shown { queue.append((covered, Date())) }
        show(notice)
    }

    private func show(_ notice: Notice) {
        withAnimation(.snappy) { shown = notice }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Notice.seconds))
            guard let self, self.shown?.id == notice.id else { return }
            withAnimation(.snappy) { self.shown = nil }
            self.showNext()
        }
    }

    /// Settings: shows a message's example on the closed notch, right now.
    func tryOut(_ kind: Notice.Kind) {
        let notice = Notice(kind: kind, word: kind.example)
        if Prefs.celebrations, notice.animation != nil { reaction = notice }
        show(notice)
    }

    /// The next message in line, most important first. Old ones are dropped: they're not news any more.
    func showNext() {
        guard shown == nil, needsLine == nil else { return }
        queue.removeAll { Date().timeIntervalSince($0.at) > Notice.stale }
        guard let next = queue.indices.max(by: { (queue[$0].notice.rank, -$0) < (queue[$1].notice.rank, -$1) }) else { return }
        show(queue.remove(at: next).notice)
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
