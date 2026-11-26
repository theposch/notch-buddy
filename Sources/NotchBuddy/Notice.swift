import SwiftUI

/// Something that just happened: a session finishing, tests breaking, a push, usage running low.
/// Clawd plays its animation, the row says it for a few seconds, and, when you've chosen to see
/// that kind in Settings, the closed notch says it too ("Pushed to main").
struct Notice: Equatable {
    /// Every moment the notch can tell you about. The raw values are kept in Settings, so don't rename them.
    enum Kind: String, CaseIterable {
        // Needs you: shown for as long as Claude waits, not for a few seconds.
        case askToRun, question, plan, stillWaiting
        // Sessions
        case started, todosDone, finished, longFinished, stopped, error
        // Tests
        case testsBroke, testsFixed
        // Git and GitHub
        case committed, pushed, prOpened, checksPassed, merged
        // Your project
        case preview, bigChange
        // Limits
        case usageLow, usagePace, usageOut, usageReset, memoryFull, makingRoom
        // Clawd only, never on the closed notch: they happen too often to be news.
        case testsPassed, helpersDone
    }

    var kind: Kind
    /// What the closed notch and the row say: "Fixed it!", "Pushed to main".
    var word: String
    /// A bit more for the row: "Tests pass again · 91 passed".
    var detail: String?
    /// Tells two notices of the same kind apart, so each one plays.
    var id = UUID()
    /// Failing again after failing before: still worth a facepalm, not worth opening the notch.
    var quiet = false

    /// How long the row and the closed notch show it.
    static let seconds: Double = 4.5
    /// Waiting longer than this for a turn on the closed notch, it's old news and dropped.
    static let stale: Double = 20

    /// The animation on Clawd's page.
    var animation: String? {
        switch kind {
        case .askToRun, .question, .plan, .stillWaiting, .usageOut: nil   // Clawd's mode already says it
        case .started: "wave"
        case .todosDone: "confetti"
        case .finished, .testsPassed: "hop"
        case .longFinished: "micdrop"
        case .stopped: "rain"
        case .error: "dizzy"
        case .testsBroke: "facepalm"
        case .testsFixed: "fixed"
        case .committed: "carry"
        case .pushed: "catapult"
        case .prOpened: "mail"
        case .checksPassed: "trophy"
        case .merged: "merged"
        case .preview: "web"
        case .bigChange: "bigone"
        case .usageLow, .usagePace, .memoryFull: "sweat"
        case .usageReset: "coffee"
        case .makingRoom: "compact"
        case .helpersDone: "highfive"
        }
    }

    enum Tone { case needs, bad, good, progress, quiet }

    var tone: Tone { kind.tone }

    /// A more important message never gets covered by a less important one.
    var rank: Int {
        switch tone {
        case .needs: 4
        case .bad: 3
        case .good: 2
        case .progress, .quiet: 1
        }
    }

    @MainActor var color: Color { kind.color }

    /// Only news opens the notch: tests that just broke or got fixed, a merge, passing checks,
    /// a big change, an error.
    var opensNotch: Bool {
        switch kind {
        case .testsBroke, .testsFixed, .merged, .checksPassed, .bigChange, .error: !quiet
        default: false
        }
    }

    // MARK: Spotting them

    /// What happened between two moments of a session. `event` is Claude's event that caused it;
    /// `named` puts the session's name in, for when several are running.
    @MainActor
    static func spot(_ before: Session?, _ now: Session, event: String, named: Bool) -> [Notice] {
        guard let before else { return [] }
        let was = before.work, work = now.work
        let name = short(now.name)
        var found: [Notice] = []

        if work.testRuns > was.testRuns, let tests = work.tests {
            let brokeBefore = was.tests.map { !$0.ok } ?? false
            if !tests.ok { found.append(Notice(kind: .testsBroke, word: "Tests failed", detail: tests.text, quiet: brokeBefore)) }
            else if brokeBefore { found.append(Notice(kind: .testsFixed, word: "Fixed it!", detail: "Tests pass again · " + tests.text)) }
            else { found.append(Notice(kind: .testsPassed, word: "Tests pass", detail: tests.text)) }
        }
        if work.commits > was.commits { found.append(Notice(kind: .committed, word: "Committed")) }
        if work.pushes > was.pushes {
            found.append(Notice(kind: .pushed, word: now.branch.map { "Pushed to \($0)" } ?? "Pushed"))
        }
        if work.prsOpened > was.prsOpened {
            found.append(Notice(kind: .prOpened, word: work.openedPR.map { "PR #\($0) opened" } ?? "Pull request opened"))
        }
        if let server = work.server, server != was.server {
            let host = (server.host() ?? "localhost") + (server.port.map { ":\($0)" } ?? "")
            found.append(Notice(kind: .preview, word: "\(host) ready"))
        }
        if let todos = work.todos, todos.total > 1, todos.done == todos.total,
           was.todos.map({ $0.done < $0.total || $0.total != todos.total }) ?? true {
            found.append(Notice(kind: .todosDone, word: "All \(todos.total) steps done"))
        }
        if was.helpers > 0, work.helpers == 0, was.helperPeak >= 2 {
            found.append(Notice(kind: .helpersDone, word: "Helpers done", detail: "All \(was.helperPeak) helpers finished"))
        }
        if let used = now.context, used >= Prefs.limit(.memoryFull), (before.context ?? 0) < Prefs.limit(.memoryFull) {
            found.append(Notice(kind: .memoryFull, word: "Memory \(used)% full"))
        }
        if event == "PreCompact" { found.append(Notice(kind: .makingRoom, word: "Making room\u{2026}")) }

        // The turn ended.
        if now.state == .done, before.state != .done {
            if event == "StopFailure" {
                found.append(Notice(kind: .error, word: named ? "\(name) hit an error" : "Hit an error", detail: now.problem))
            } else if let since = before.workingSince, Date().timeIntervalSince(since) >= Double(Prefs.limit(.longFinished) * 60) {
                let took = SessionRow.elapsed(since, now: Date())
                found.append(Notice(kind: .longFinished, word: named ? "\(name) · \(took)" : "Done after \(took)"))
            } else {
                found.append(Notice(kind: .finished, word: named ? "\(name) is done" : "Done"))
            }
            if work.changedThisTurn >= Prefs.limit(.bigChange), let lines = work.linesText {
                found.append(Notice(kind: .bigChange, word: "Big one!", detail: lines))
            }
        }
        return found
    }

    /// What changed about a branch's pull request.
    static func spot(_ before: PullRequest?, _ now: PullRequest?) -> Notice? {
        guard let before, let now, before.number == now.number else { return nil }
        if now.merged, !before.merged { return Notice(kind: .merged, word: "Merged!", detail: "PR #\(now.number) merged") }
        if now.checks == .passed, before.checks == .running {
            return Notice(kind: .checksPassed, word: "Checks passed", detail: "PR #\(now.number)")
        }
        return nil
    }

    /// Session names can be long; the closed notch has room for a short one.
    static func short(_ name: String, to length: Int = 14) -> String {
        name.count <= length ? name : String(name.prefix(length - 1)).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }

    /// What Claude's error codes mean, for the row: "rate_limit" → "Hit the rate limit".
    static func problem(_ code: String?) -> String? {
        switch code {
        case "rate_limit": "Hit the rate limit"
        case "overloaded": "Claude's servers are busy"
        case "authentication_failed", "oauth_org_not_allowed": "Signed out"
        case "account_on_hold": "Account on hold"
        case let code?: code.replacingOccurrences(of: "_", with: " ").capitalized
        case nil: nil
        }
    }
}

// MARK: How Settings describes them

extension Notice.Kind {
    var tone: Notice.Tone {
        switch self {
        case .askToRun, .question, .plan, .stillWaiting: .needs
        case .error, .testsBroke, .usageLow, .usagePace, .memoryFull: .bad
        case .todosDone, .finished, .longFinished, .testsFixed, .checksPassed, .merged, .usageReset, .testsPassed: .good
        case .started, .committed, .pushed, .prOpened, .preview, .bigChange, .helpersDone: .progress
        case .stopped, .usageOut, .makingRoom: .quiet
        }
    }

    @MainActor var color: Color {
        if self == .merged { return NotchView.purple }
        switch tone {
        case .needs: return NotchView.amber
        case .bad: return NotchView.red
        case .good: return NotchView.green
        case .progress: return NotchView.clay
        case .quiet: return NotchView.dim
        }
    }

    /// The moment, in Settings: "Asks to run something".
    var label: String {
        switch self {
        case .askToRun: "Asks to run something"
        case .question: "Asks a question"
        case .plan: "Has a plan for you to review"
        case .stillWaiting: "Is still waiting on you"
        case .started: "A session starts"
        case .todosDone: "Its to-do list is finished"
        case .finished: "A session finishes"
        case .longFinished: "A long session finishes"
        case .stopped: "You stop a session"
        case .error: "A session ends on an error"
        case .testsBroke: "Tests break"
        case .testsFixed: "Broken tests pass again"
        case .committed: "Claude commits"
        case .pushed: "Claude pushes"
        case .prOpened: "Claude opens a pull request"
        case .checksPassed: "A pull request\u{2019}s checks pass"
        case .merged: "A pull request merges"
        case .preview: "A local preview starts"
        case .bigChange: "A big change finishes"
        case .usageLow: "Usage is running low"
        case .usagePace: "Usage will run out before it resets"
        case .usageOut: "Usage runs out"
        case .usageReset: "Usage resets"
        case .memoryFull: "The conversation is nearly full"
        case .makingRoom: "Claude makes room in it"
        case .testsPassed: "Tests pass"
        case .helpersDone: "Helpers finish"
        }
    }

    /// A limit you can set, in the same row: "after [5 min]".
    struct Limit {
        var before: String
        var options: [Int]
        var unit: String
        var standard: Int

        func text(_ value: Int) -> String {
            unit == "%" ? "\(value)%" : "\(value.formatted()) \(unit)"
        }
    }

    var limit: Limit? {
        switch self {
        case .stillWaiting: Limit(before: "after", options: [2, 5, 10, 15], unit: "min", standard: 5)
        case .longFinished: Limit(before: "longer than", options: [5, 10, 20, 30, 60], unit: "min", standard: 10)
        case .bigChange: Limit(before: "over", options: [200, 500, 1000, 2000], unit: "lines", standard: 500)
        case .usageLow: Limit(before: "under", options: [5, 10, 15, 20, 25, 30, 40, 50], unit: "%", standard: 10)
        case .memoryFull: Limit(before: "at", options: [70, 80, 90, 95], unit: "%", standard: 90)
        default: nil
        }
    }

    /// What the closed notch would say, for the preview in Settings.
    var example: String {
        switch self {
        case .askToRun: "Run npm test?"
        case .question: "Has a question"
        case .plan: "Plan ready"
        case .stillWaiting: "Still waiting · \(Prefs.limit(self))m"
        case .started: "New: app build"
        case .todosDone: "All 7 steps done"
        case .finished: "Done"
        case .longFinished: "Done after 24m"
        case .stopped: "Stopped"
        case .error: "Hit an error"
        case .testsBroke: "Tests failed"
        case .testsFixed: "Fixed it!"
        case .committed: "Committed"
        case .pushed: "Pushed to main"
        case .prOpened: "PR #88 opened"
        case .checksPassed: "Checks passed"
        case .merged: "Merged!"
        case .preview: "localhost:5173 ready"
        case .bigChange: "Big one!"
        case .usageLow: "\(Prefs.limit(self))% left"
        case .usagePace: "Out by 3:40 PM"
        case .usageOut: "Back at 7:00 PM"
        case .usageReset: "Fresh 5 hours"
        case .memoryFull: "Memory \(Prefs.limit(self))% full"
        case .makingRoom: "Making room\u{2026}"
        case .testsPassed: "Tests pass"
        case .helpersDone: "Helpers done"
        }
    }

    /// The ones that start switched on: things you'd act on, or want to know right away.
    static let important: Set<Notice.Kind> = [.askToRun, .question, .plan, .stillWaiting, .finished, .longFinished, .error,
                                              .testsBroke, .testsFixed, .merged, .usageLow, .usagePace, .usageOut, .memoryFull]

    /// Settings groups them by topic.
    static let topics: [(title: String, note: String?, kinds: [Notice.Kind])] = [
        ("Needs you", "Claude is stuck until you answer, so these stay until you do.", [.askToRun, .question, .plan, .stillWaiting]),
        ("Sessions", nil, [.started, .todosDone, .finished, .longFinished, .stopped, .error]),
        ("Tests", nil, [.testsBroke, .testsFixed]),
        ("Git and GitHub", nil, [.committed, .pushed, .prOpened, .checksPassed, .merged]),
        ("Your project", nil, [.preview, .bigChange]),
        ("Limits", nil, [.usageLow, .usagePace, .usageOut, .usageReset, .memoryFull, .makingRoom]),
    ]

    /// Everything Settings lists (the Clawd-only ones aren't there).
    static var listed: [Notice.Kind] { topics.flatMap(\.kinds) }
}
