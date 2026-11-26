import AppKit
import Foundation
import Testing
@testable import NotchBuddy

/// What you chose to see on session rows (Settings > Sessions).
struct RowPrefsTests {
    func fresh() -> UserDefaults {
        let name = "nb-rows-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func startsBalanced() {
        let d = fresh()
        #expect(RowPrefs.preset(d) == .balanced)
        #expect(RowPrefs.place(.time, d) == .glance)
        #expect(RowPrefs.place(.branch, d) == .hover)
        #expect(RowPrefs.place(.cost, d) == .off)
        #expect(!RowPrefs.always(d))
    }

    @Test func presetsAndYourOwnMix() {
        let d = fresh()
        RowPrefs.apply(.everything, d)
        #expect(RowPrefs.preset(d) == .everything)
        #expect(RowPrefs.always(d))
        #expect(RowPrefs.place(.cost, d) == .glance)
        RowPrefs.set(.cost, .off, d)
        #expect(RowPrefs.preset(d) == nil)            // Custom
        RowPrefs.apply(.minimal, d)
        #expect(RowPrefs.preset(d) == .minimal)
        #expect(RowPiece.allCases.filter { RowPrefs.place($0, d) != .off } == [.context, .time])
    }

    /// A branch name has no small form, so it can't sit "at a glance" even if a setting says so.
    @Test func wordsOnlyPiecesNeverSitAtAGlance() {
        let d = fresh()
        for piece in [RowPiece.branch, .lines, .server] {
            #expect(!piece.hasGlance)
            RowPrefs.set(piece, .glance, d)
            #expect(RowPrefs.place(piece, d) == .hover)
        }
        #expect(RowPrefs.Preset.everything.place(.branch) == .hover)
    }
}

/// The details line follows those choices.
@MainActor
struct RowDetailTests {
    func session() -> Session {
        var s = Session(id: "a", folder: "app", state: .working, color: Prefs.clay)
        s.branch = "main"
        s.model = "Opus 5.5"
        s.context = 57
        s.cost = 1.84
        s.workingSince = Date(timeIntervalSince1970: 1000)
        s.work.tests = .init(passed: 42, failed: nil, ok: true)
        s.work.helpers = 2
        s.work.server = URL(string: "http://localhost:6006")
        return s
    }
    let now = Date(timeIntervalSince1970: 1000 + 252)

    @Test func onHoverPiecesAreInTheDetails() {
        let all = session().details(shortcut: false, account: (name: "Work", color: "#D97757"), now: now) { _ in .hover }
        #expect(all == [.branch("main"), .tests(.init(passed: 42, failed: nil, ok: true)), .server(URL(string: "http://localhost:6006")!),
                        .helpers(2), .model("Opus 5.5"), .account(name: "Work", color: "#D97757"), .context(57), .time("running 4m"), .cost(1.84)])
        #expect(Detail.helpers(2).text == "2 helpers at work")
        #expect(Detail.context(57).text == "57% full")
    }

    @Test func offPiecesAreGone() {
        #expect(session().details(shortcut: false, now: now) { _ in .off }.isEmpty)
        #expect(session().details(shortcut: true, now: now) { _ in .off } == [.keys])   // the shortcut hint always shows
    }

    /// An icon for the tests says less than "42 passed", so the words still come on hover.
    /// A model tag already says everything, so it isn't repeated.
    @Test func atAGlancePiecesOnlyRepeatWhenTheWordsSayMore() {
        let glance = session().details(shortcut: false, account: (name: "Work", color: "#D97757"), now: now) { _ in .glance }
        #expect(glance == [.tests(.init(passed: 42, failed: nil, ok: true)), .context(57)])
    }

    @Test func timeReadsDifferentlyOnTheRowAndInTheDetails() {
        var s = session()
        #expect(s.timeText(now: now) == "4m")
        #expect(s.timeText(now: now, long: true) == "running 4m")
        s.state = .done
        s.changed = Date(timeIntervalSince1970: 1000)
        #expect(s.timeText(now: now) == "4m")
        #expect(s.timeText(now: now, long: true) == "4m ago")
        #expect(s.timeText(now: Date(timeIntervalSince1970: 1010), long: true) == "now")
    }

    @Test func thisMacHasEverySymbolTheRowsUse() {
        for name in Symbols.all + SettingsPane.allCases.map(\.symbol) + ["pencil", "gearshape", "power"] {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }
}

/// How Claude's last answer began, for a finished row.
@MainActor
struct LastWordsTests {
    func line(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) }

    @Test func plainWordsFromAnAnswer() {
        #expect(ConversationSize.tidy("## Done\n\n**Published** the page and pushed to `main`.") == "Done")
        #expect(ConversationSize.tidy("\n\n- **Published** the page and pushed to `main`.") == "Published the page and pushed to main.")
        #expect(ConversationSize.tidy("---\n\n") == nil)
        #expect(ConversationSize.tidy(nil) == nil)
        let long = ConversationSize.tidy(String(repeating: "word ", count: 80))
        #expect(long?.count == 160)
        #expect(long?.hasSuffix("\u{2026}") == true)
    }

    @Test func theNewestAnswerInTheLogWins() {
        // Newest line first, as the helper reads the log. Helpers' own messages don't count.
        let lines = [
            line(["type": "user", "message": ["content": "thanks"]]),
            line(["type": "assistant", "isSidechain": true, "message": ["content": [["type": "text", "text": "A helper's note."]]]]),
            line(["type": "assistant", "message": ["content": [["type": "tool_use", "name": "Bash"]]]]),
            line(["type": "assistant", "message": ["content": [["type": "text", "text": "Thinking aloud."], ["type": "text", "text": "All 42 tests pass."]]]]),
            line(["type": "assistant", "message": ["content": [["type": "text", "text": "An older answer."]]]]),
        ]
        #expect(ConversationSize.lastWords(in: lines) == "All 42 tests pass.")
        #expect(ConversationSize.lastWords(in: []) == nil)
    }

    @Test func aFinishedRowKeepsThemUntilYourNextMessage() {
        let model = NotchModel()
        model.live = false
        model.hideIdle = false
        func send(_ name: String, extra: [String: Any] = [:]) {
            var e: [String: Any] = ["hook_event_name": name, "session_id": "a", "cwd": "/x/app"]
            e.merge(extra) { $1 }
            model.handle(try! JSONSerialization.data(withJSONObject: e))
        }
        send("UserPromptSubmit")
        send("Stop", extra: [ConversationSize.lastKey: "All 42 tests pass."])
        #expect(model.sessions.first?.lastWords == "All 42 tests pass.")
        send("UserPromptSubmit")
        #expect(model.sessions.first?.lastWords == nil)
        // Newer versions of Claude Code hand the answer over themselves.
        send("Stop", extra: ["last_assistant_message": "## Summary\nShipped."])
        #expect(model.sessions.first?.lastWords == "Summary")
    }
}

/// The open notch grows to fit what it shows.
@MainActor
struct NotchSizeTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        m.hideIdle = false
        return m
    }()

    func send(_ name: String, session: String, tool: String = "Bash", input: [String: Any] = ["command": "npm test"]) {
        let e: [String: Any] = ["hook_event_name": name, "session_id": session, "cwd": "/x/\(session)", "tool_name": tool, "tool_input": input]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func aRowAndACard() {
        send("UserPromptSubmit", session: "a")
        let width = model.openWidth
        let one = model.openSize.height
        #expect(one == model.geometry.barHeight + NotchModel.listTop + NotchModel.listBottom + NotchModel.rowHeight)
        send("PermissionRequest", session: "b")
        let card = NotchModel.Card.margin + NotchModel.Card.height(commandLines: 1) + NotchModel.Card.below
        #expect(model.openSize.height == one + card)
        #expect(model.height(of: model.rows[0], width: width) == card)          // needs you: on top, as a card
        // A longer command makes the card taller, up to three lines.
        send("PermissionRequest", session: "b", input: ["command": String(repeating: "x", count: 4000)])
        #expect(model.height(of: model.rows[0], width: width) == NotchModel.Card.margin + NotchModel.Card.height(commandLines: 3) + NotchModel.Card.below)
        // A question has no command to show.
        send("PreToolUse", session: "c", tool: "AskUserQuestion", input: [:])
        #expect(model.height(of: model.rows.first { $0.id == "c" }!, width: width) == NotchModel.Card.margin + NotchModel.Card.height(commandLines: 0) + NotchModel.Card.below)
    }

    @Test func theNeedsYouPillGetsRoomOnTheClosedNotch() {
        send("UserPromptSubmit", session: "a")
        let before = model.wingWidth
        send("PermissionRequest", session: "a")
        let text = (model.needsLine! as NSString).size(withAttributes: [.font: NotchModel.wingFont]).width
        #expect(model.wingWidth == ceil(text) + 38)
        #expect(model.wingWidth > before)
    }
}
