import Foundation
import Testing
@testable import NotchBuddy

/// The short messages: what the row and the closed notch say when something happens,
/// when Clawd reacts, and when the notch peeks open for it.
@MainActor
@Suite(.serialized)
struct NoticeTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        // Plenty of usage left, whatever another test saved.
        let usage: [String: Any] = ["hook_event_name": Usage.event, "used_percentage": 0,
                                    "resets_at": Date().timeIntervalSince1970 + 3600]
        m.handle(try! JSONSerialization.data(withJSONObject: usage))
        return m
    }()

    func send(_ name: String, tool: String? = nil, extra: [String: Any] = [:]) {
        var e: [String: Any] = ["hook_event_name": name, "session_id": "a", "cwd": "/x/app"]
        if let tool { e["tool_name"] = tool }
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func testRun(passes: Bool) {
        send(passes ? "PostToolUse" : "PostToolUseFailure", tool: "Bash", extra: [
            "tool_input": ["command": "swift test"],
            "tool_response": ["stdout": passes ? "Test run with 91 tests passed" : "2 tests failed", "stderr": ""],
            "error": passes ? "" : "2 tests failed",
        ])
    }

    func bash(_ command: String, output: String = "") {
        send("PostToolUse", tool: "Bash", extra: ["tool_input": ["command": command],
                                                  "tool_response": ["stdout": output, "stderr": ""]])
    }

    /// Runs `body` with only these messages switched on, then puts your choice back.
    func with(_ kinds: Set<Notice.Kind>, _ body: () -> Void) {
        Prefs.messages = kinds
        defer { UserDefaults.standard.removeObject(forKey: "messages") }
        body()
    }

    var notice: Notice? { model.sessions.first?.notice }

    @Test func testsBreakingAndGettingFixed() {
        var peeks = 0
        model.onPeek = { peeks += 1 }
        send("UserPromptSubmit")
        testRun(passes: true)
        #expect(notice?.kind == .testsPassed)
        #expect(model.shown == nil)                 // passing is normal: Clawd hops, the notch stays quiet
        #expect(peeks == 0)
        testRun(passes: false)
        #expect(notice?.kind == .testsBroke)
        #expect(notice?.detail == "2 failed")
        #expect(model.rightText == "Tests failed")
        #expect(peeks == 1)                         // just broke: news
        testRun(passes: false)
        #expect(peeks == 1)                         // still broken: no peek
        testRun(passes: true)
        #expect(notice?.word == "Fixed it!")
        #expect(notice?.detail == "Tests pass again · 91 passed")
        #expect(peeks == 2)
    }

    @Test func otherCommandsSayNothing() {
        send("UserPromptSubmit")
        bash("ls", output: "3 passed")
        #expect(notice == nil)
    }

    @Test func gitAndGitHub() {
        with(Set(Notice.Kind.listed)) {
            send("UserPromptSubmit")
            bash("git add -A && git commit -m 'Tidy'", output: "[main 1a2b3c] Tidy")
            #expect(notice?.word == "Committed")
            #expect(model.rightText == "Committed")
            bash("git push origin main")
            #expect(notice?.word.hasPrefix("Pushed") == true)
            #expect(model.rightText == "Committed")      // just as important: it waits its turn
            bash("gh pr create --fill", output: "https://github.com/me/app/pull/42\n")
            #expect(notice?.word == "PR #42 opened")
            bash("git status")
            #expect(model.sessions.first?.work.commits == 1)
        }
    }

    @Test func aTurnEnding() {
        send("UserPromptSubmit")
        send("Stop")
        #expect(notice?.word == "Done")
        #expect(model.rightText == "Done")
    }

    @Test func aTurnEndingOnAnError() {
        send("UserPromptSubmit")
        send("StopFailure", extra: ["error": "rate_limit"])
        #expect(notice?.kind == .error)
        #expect(notice?.detail == Notice.problem("rate_limit"))
        #expect(model.rightText == "Hit an error")
    }

    @Test func stoppingASession() {
        send("UserPromptSubmit")
        send("SessionEnd", extra: ["reason": "prompt_input_exit"])
        #expect(model.sessions.isEmpty)
        #expect(model.shown == nil)                 // "Stopped" is off unless you choose it
        with([.stopped]) {
            send("UserPromptSubmit")
            send("SessionEnd", extra: ["reason": "other"])
            #expect(model.rightText == "Stopped")
        }
    }

    @Test func newSessionsOnlyWhenTheyReallyStart() {
        with([.started]) {
            send("SessionStart", extra: ["source": "resume"])
            #expect(model.shown == nil)
            send("SessionEnd", extra: ["reason": "clear"])
            send("SessionStart", extra: ["source": "startup"])
            #expect(model.rightText == "New: app")
        }
    }

    @Test func makingRoom() {
        with([.makingRoom]) {
            send("UserPromptSubmit")
            send("PreCompact")
            #expect(model.rightText == "Making room\u{2026}")
            #expect(model.sessions.first?.state == .working)
        }
    }

    @Test func needsYouComesFirst() {
        send("UserPromptSubmit")
        send("PermissionRequest", tool: "Bash", extra: ["tool_input": ["command": "npm test"]])
        let asking = model.rightText
        #expect(asking != nil && asking == model.needsLine)
        model.post([Notice(kind: .merged, word: "Merged!")], for: nil)
        #expect(model.shown == nil)                 // waits behind the question
        #expect(model.rightText == asking)
        send("PostToolUse", tool: "Bash", extra: ["tool_input": ["command": "npm test"]])
        #expect(model.rightText == "Merged!")      // answered: now it's its turn
    }

    @Test func moreImportantGoesFirst() {
        with(Set(Notice.Kind.listed)) {
            model.post([Notice(kind: .committed, word: "Committed")], for: nil)
            model.post([Notice(kind: .testsBroke, word: "Tests failed")], for: nil)
            #expect(model.rightText == "Tests failed")
            model.post([Notice(kind: .preview, word: "localhost:5173 ready")], for: nil)
            #expect(model.rightText == "Tests failed")
        }
    }

    @Test func switchedOffMessagesStillGetAReaction() {
        with([]) {
            send("UserPromptSubmit")
            testRun(passes: false)
            #expect(model.shown == nil)
            #expect(model.reaction?.kind == .testsBroke)
            #expect(notice?.kind == .testsBroke)      // the open notch's row still says it
        }
    }

    @Test func reactionsSwitchedOff() {
        UserDefaults.standard.set(false, forKey: "celebrations")
        defer { UserDefaults.standard.removeObject(forKey: "celebrations") }
        send("UserPromptSubmit")
        testRun(passes: false)
        #expect(model.reaction == nil)
        #expect(model.rightText == "Tests failed")
    }

    @Test func bigChangesCountFromYourLatestMessage() {
        let edit: [String: Any] = ["tool_input": ["file_path": "/x/app/a.swift"],
                                   "tool_response": ["type": "create", "content": String(repeating: "line\n", count: 400)]]
        send("UserPromptSubmit")
        send("PostToolUse", tool: "Write", extra: edit)
        send("PostToolUse", tool: "Write", extra: edit)
        send("Stop")
        #expect(notice?.kind == .bigChange)
        #expect(notice?.detail == "+800 \u{2212}0 · 1 file")
        #expect(model.reaction?.kind == .bigChange)
        // The next turn changes little: no big one, even though the session's total is big.
        send("UserPromptSubmit")
        send("PostToolUse", tool: "Write", extra: ["tool_input": ["file_path": "/x/app/b.swift"],
                                                    "tool_response": ["type": "create", "content": "one\n"]])
        send("Stop")
        #expect(model.sessions.first?.work.changedThisTurn == 1)
        #expect(notice?.kind == .finished)
    }

    @Test func aTeamOfHelpersFinishing() {
        send("UserPromptSubmit")
        send("SubagentStart"); send("SubagentStart"); send("SubagentStart")
        send("SubagentStop"); send("SubagentStop")
        #expect(notice == nil)
        send("SubagentStop")
        #expect(notice?.kind == .helpersDone)
        #expect(notice?.detail == "All 3 helpers finished")
        #expect(model.shown == nil)                 // Clawd only
    }

    @Test func oneHelperIsNoParty() {
        send("UserPromptSubmit")
        send("SubagentStart"); send("SubagentStop")
        #expect(notice == nil)
    }

    @Test func pullRequests() {
        let url = URL(string: "https://example.com/pr/87")!
        let running = PullRequest(number: 87, url: url, checks: .running)
        var passed = running; passed.checks = .passed
        var merged = passed; merged.merged = true
        #expect(Notice.spot(running, passed)?.kind == .checksPassed)
        #expect(Notice.spot(passed, merged)?.kind == .merged)
        #expect(Notice.spot(passed, merged)?.detail == "PR #87 merged")
        #expect(Notice.spot(nil, merged) == nil)                     // first look: nothing changed yet
        var other = merged; other.number = 88
        #expect(Notice.spot(passed, other) == nil)                   // a different pull request
        #expect(Notice.spot(passed, passed) == nil)
    }

    @Test func limits() {
        #expect(Prefs.limit(.usageLow) == 10)
        Prefs.setLimit(.usageLow, 25)
        defer { UserDefaults.standard.removeObject(forKey: "limit.usageLow") }
        #expect(Prefs.limit(.usageLow) == 25)
        #expect(model.lowUsage == 25)
        #expect(Notice.Kind.usageLow.example == "25% left")
    }

    @Test func everyListedMessageHasAPlaceInSettings() {
        let listed = Notice.Kind.listed
        #expect(Set(listed).count == listed.count)                   // none twice
        #expect(Set(listed).union([.testsPassed, .helpersDone]) == Set(Notice.Kind.allCases))
        #expect(Notice.Kind.important.isSubset(of: Set(listed)))
    }
}
