import Foundation
import Testing
@testable import NotchBuddy

/// Lines changed, tests, servers, to-dos and helpers, read from Claude's events.
struct WorkTests {
    @Test func linesFromClaudesPatch() {
        let response: [String: Any] = ["structuredPatch": [["lines": [" a", "-b", "+c", "+d"]]]]
        #expect(Work.lines(input: [:], response: response) == (2, 1))
        #expect(Work.lines(input: [:], response: ["type": "create", "content": "1\n2\n3\n"]) == (3, 0))
        // No patch: only the lines that differ count.
        #expect(Work.lines(input: ["old_string": "a\nb\nc", "new_string": "a\nB\nB2\nc"], response: nil) == (2, 1))
    }

    @Test func spotsTestRuns() {
        #expect(Work.runsTests("cd app && swift test 2>&1 | tail"))
        #expect(Work.runsTests("npm run test"))
        #expect(Work.runsTests("python -m pytest -q"))
        #expect(!Work.runsTests("grep -rn \"test\" Sources"))
        #expect(!Work.runsTests("ls Tests"))
    }

    @Test func readsTestResults() {
        #expect(Work.tests(in: "✔ Test run with 78 tests in 17 suites passed after 0.5 seconds.", failed: false)
                == .init(passed: 78, failed: nil, ok: true))
        #expect(Work.tests(in: "Tests: 2 failed, 40 passed, 42 total", failed: true).text == "2 failed")
        #expect(Work.tests(in: "===== 5 passed in 0.12s =====", failed: false).text == "5 passed")
        #expect(Work.tests(in: "boom", failed: true).text == "Tests failed")
    }

    @Test func findsLocalServers() {
        #expect(Work.localServer(in: "  ➜  Local:   http://localhost:5173/\n")?.absoluteString == "http://localhost:5173/")
        #expect(Work.localServer(in: "listening on http://0.0.0.0:8080")?.absoluteString == "http://localhost:8080")
        #expect(Work.localServer(in: "see https://example.com") == nil)
    }

    @Test func notesEverything() {
        var work = Work()
        work.note("PreToolUse", tool: "TodoWrite", event: ["tool_input": ["todos": [
            ["content": "A", "status": "completed", "activeForm": "Doing A"],
            ["content": "B", "status": "in_progress", "activeForm": "Doing B"],
            ["content": "C", "status": "pending", "activeForm": "Doing C"]]]])
        #expect(work.todos == .init(done: 1, total: 3, current: "Doing B"))
        work.note("SubagentStart", tool: "", event: [:])
        work.note("SubagentStart", tool: "", event: [:])
        work.note("SubagentStop", tool: "", event: [:])
        #expect(work.helpers == 1)
        work.note("PostToolUse", tool: "Edit", event: ["tool_input": ["file_path": "/a/x.swift"],
                                                      "tool_response": ["structuredPatch": [["lines": ["+1", "-2"]]]]])
        #expect(work.linesText == "+1 \u{2212}1 · 1 file")
        work.note("PostToolUseFailure", tool: "Bash", event: ["tool_input": ["command": "npm test"], "error": "Tests: 3 failed"])
        #expect(work.tests?.ok == false)
        #expect(work.lastCommand == "npm test")
    }
}

/// The branch, pull requests and today's figures.
struct BranchAndRecapTests {
    @Test func readsTheBranch() throws {
        let folder = NSTemporaryDirectory() + "repo-\(UUID())"
        try FileManager.default.createDirectory(atPath: folder + "/.git", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: folder + "/Sources/deep", withIntermediateDirectories: true)
        try "ref: refs/heads/fix-login\n".write(toFile: folder + "/.git/HEAD", atomically: true, encoding: .utf8)
        #expect(Git.branch(at: folder + "/Sources/deep") == "fix-login")
        // A worktree: .git is a file pointing at the real folder.
        let tree = NSTemporaryDirectory() + "tree-\(UUID())"
        try FileManager.default.createDirectory(atPath: tree + "/real", withIntermediateDirectories: true)
        try "0123456789abcdef\n".write(toFile: tree + "/real/HEAD", atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: tree + "/work", withIntermediateDirectories: true)
        try "gitdir: \(tree)/real\n".write(toFile: tree + "/work/.git", atomically: true, encoding: .utf8)
        #expect(Git.branch(at: tree + "/work") == "0123456")
        #expect(Git.branch(at: "/") == nil)
    }

    @Test func readsPullRequests() {
        func pr(_ checks: [[String: Any]], state: String = "OPEN") -> PullRequest? {
            let json: [String: Any] = ["number": 87, "url": "https://github.com/o/r/pull/87", "state": state, "statusCheckRollup": checks]
            return PullRequest.parse(try! JSONSerialization.data(withJSONObject: json))
        }
        #expect(pr([["status": "COMPLETED", "conclusion": "SUCCESS"], ["state": "SUCCESS"]])?.checks == .passed)
        #expect(pr([["status": "IN_PROGRESS", "conclusion": ""], ["status": "COMPLETED", "conclusion": "SUCCESS"]])?.checks == .running)
        #expect(pr([["status": "COMPLETED", "conclusion": "FAILURE"], ["status": "QUEUED"]])?.checks == .failed)
        #expect(pr([])?.text == "PR #87")
        #expect(pr([], state: "MERGED")?.text == "PR #87 · merged")
        #expect(PullRequest.parse(Data("no".utf8)) == nil)
    }

    @Test func todayLine() {
        var t = Today(day: Today.dayName())
        #expect(t.line == nil)
        t.sessions = ["a", "b"]
        t.seconds = 2 * 3600 + 40 * 60
        t.files = ["x", "y"]
        t.added = 412
        t.removed = 96
        #expect(t.line == "Today: 2 sessions · 2h 40m of work · 2 files · +412 \u{2212}96")
    }

    @MainActor @Test func detailsWrapWhenLong() {
        let short: [Detail] = [.branch("main"), .lines("+1 \u{2212}1 · 1 file")]
        #expect(NotchModel.detailLines(short, width: 380) == 1)
        let long = short + [.tests(.init(passed: 42, failed: nil, ok: true)), .server(URL(string: "http://localhost:4174")!),
                            .todo("3 of 7 · Wiring up the settings window"), .cost(1.84)]
        #expect(NotchModel.detailLines(long, width: 380) == 2)
        #expect(NotchModel.detailLines([], width: 380) == 0)
    }
}

/// The model puts it together.
@MainActor
struct CleanRowModelTests {
    let model: NotchModel = { let m = NotchModel(); m.live = false; return m }()

    func send(_ name: String, tool: String? = nil, extra: [String: Any] = [:]) {
        var e: [String: Any] = ["hook_event_name": name, "session_id": "a", "cwd": "/x/app"]
        if let tool { e["tool_name"] = tool }
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func helpersDontChangeTheState() {
        send("Stop")
        send("SubagentStart")
        #expect(model.sessions.first?.state == .done)
        #expect(model.sessions.first?.work.helpers == 1)
    }

    @Test func planRowsAndShortcuts() {
        send("PermissionRequest", tool: "ExitPlanMode")
        #expect(model.sessions.first?.plan == true)
        #expect(model.sessions.first?.summary == "Plan ready to review")
        #expect(model.shortcutTarget == nil)                       // plans need reading, not a key press
        send("PostToolUse", tool: "ExitPlanMode")
        #expect(model.sessions.first?.plan == false)
    }

    @Test func branchAndFailedCommands() {
        send("PreToolUse", tool: "Bash", extra: [Git.branchKey: "main"])
        #expect(model.sessions.first?.branch == "main")
        send("PostToolUseFailure", tool: "Bash", extra: ["tool_input": ["command": "swift test"], "error": "1 failed"])
        #expect(model.sessions.first?.state == .working)
        #expect(model.sessions.first?.work.tests?.ok == false)
        #expect(model.sessions.first?.details(shortcut: false).first == .branch("main"))
    }

    @Test func weeklyUsageAndCost() {
        send("UserPromptSubmit")
        let e: [String: Any] = ["hook_event_name": Usage.event, "week_used": 40.0, "week_resets": Date().timeIntervalSince1970 + 86400,
                                "session_id": "a", "cost": 1.84]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
        #expect(model.weekLeft == 60)
        #expect(model.sessions.first?.cost == 1.84)
    }
}
