import Foundation
import Testing
@testable import NotchBuddy

/// When Clawd celebrates (or facepalms), and when the notch peeks open for it.
@MainActor
struct CheerTests {
    let model: NotchModel = { let m = NotchModel(); m.live = false; return m }()

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

    var cheer: Cheer? { model.sessions.first?.cheer }

    @Test func testsBreakingAndGettingFixed() {
        var peeks = 0
        model.onPeek = { peeks += 1 }
        send("UserPromptSubmit")
        testRun(passes: true)
        #expect(cheer?.kind == .passed)
        #expect(peeks == 0)                         // passing is normal: no peek
        testRun(passes: false)
        #expect(cheer?.kind == .failed)
        #expect(cheer?.text == "2 failed")
        #expect(peeks == 1)                         // just broke: news
        testRun(passes: false)
        #expect(cheer?.opensNotch == false)         // still broken: a facepalm, no peek
        testRun(passes: true)
        #expect(cheer?.kind == .fixed)
        #expect(cheer?.text == "Tests pass again · 91 passed")
        #expect(peeks == 2)
        #expect(model.cheer == cheer)               // the closed notch says it too
        #expect(model.rightText == "Fixed it!")
    }

    @Test func otherCommandsDontCheer() {
        send("UserPromptSubmit")
        send("PostToolUse", tool: "Bash", extra: ["tool_input": ["command": "ls"], "tool_response": ["stdout": "3 passed"]])
        #expect(cheer == nil)
    }

    @Test func bigChangesCountFromYourLatestMessage() {
        let edit: [String: Any] = ["tool_input": ["file_path": "/x/app/a.swift"],
                                   "tool_response": ["type": "create", "content": String(repeating: "line\n", count: 400)]]
        send("UserPromptSubmit")
        send("PostToolUse", tool: "Write", extra: edit)
        send("PostToolUse", tool: "Write", extra: edit)
        send("Stop")
        #expect(cheer?.kind == .bigChange)
        #expect(cheer?.text == "+800 \u{2212}0 · 1 file")
        // The next turn changes little: no cheer, even though the session's total is big.
        send("UserPromptSubmit")
        send("PostToolUse", tool: "Write", extra: ["tool_input": ["file_path": "/x/app/b.swift"],
                                                    "tool_response": ["type": "create", "content": "one\n"]])
        send("Stop")
        #expect(model.sessions.first?.work.changedThisTurn == 1)
        #expect(Cheer.after(model.sessions.first, model.sessions.first!) == nil)
    }

    @Test func aTeamOfHelpersFinishing() {
        send("UserPromptSubmit")
        send("SubagentStart"); send("SubagentStart"); send("SubagentStart")
        send("SubagentStop"); send("SubagentStop")
        #expect(cheer == nil)
        send("SubagentStop")
        #expect(cheer?.kind == .helpersDone)
        #expect(cheer?.text == "All 3 helpers finished")
        #expect(cheer?.opensNotch == false)
    }

    @Test func oneHelperIsNoParty() {
        send("UserPromptSubmit")
        send("SubagentStart"); send("SubagentStop")
        #expect(cheer == nil)
    }

    @Test func pullRequests() {
        let url = URL(string: "https://example.com/pr/87")!
        let running = PullRequest(number: 87, url: url, checks: .running)
        var passed = running; passed.checks = .passed
        var merged = passed; merged.merged = true
        #expect(Cheer.after(running, passed)?.kind == .checksPassed)
        #expect(Cheer.after(passed, merged)?.kind == .merged)
        #expect(Cheer.after(passed, merged)?.text == "PR #87 merged")
        #expect(Cheer.after(nil, merged) == nil)                     // first look: nothing changed yet
        var other = merged; other.number = 88
        #expect(Cheer.after(passed, other) == nil)                   // a different pull request
        #expect(Cheer.after(passed, passed) == nil)
    }

    @Test func switchedOff() {
        UserDefaults.standard.set(false, forKey: "celebrations")
        defer { UserDefaults.standard.removeObject(forKey: "celebrations") }
        send("UserPromptSubmit")
        testRun(passes: false)
        #expect(cheer == nil)
    }
}
