import Foundation
import Testing
@testable import NotchBuddy

/// How rows react to Claude Code events.
@MainActor
struct NotchModelTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.soundsOn = false
        return m
    }()

    func send(_ name: String, session: String = "s1", tool: String = "Bash", extra: [String: Any] = [:]) {
        var e: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/Users/me/\(session)",
                                "tool_name": tool, "tool_input": ["command": "npm test"]]
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func permissionRequestShowsSummary() {
        send("PermissionRequest")
        #expect(model.sessions.first?.state == .waiting)
        #expect(model.sessions.first?.summary == "Run: npm test")
    }

    @Test func questionShowsNoButtons() {
        send("PreToolUse", tool: "AskUserQuestion")
        #expect(model.sessions.first?.summary == "Has a question")
        #expect(model.sessions.first?.canAnswer == false)
    }

    @Test func answeredInTerminalClearsTheRequest() {
        send("PermissionRequest")
        send("PostToolUse")
        #expect(model.sessions.first?.state == .working)
        #expect(model.sessions.first?.summary == nil)
        #expect(model.sessions.first?.canAnswer == false)
    }

    @Test func reminderKeepsTheRequest() {
        send("PermissionRequest")
        send("Notification", extra: ["notification_type": "permission_prompt", "message": "Claude needs your permission"])
        #expect(model.sessions.first?.summary == "Run: npm test")
    }

    @Test func needsYouFirstThenNewest() {
        send("UserPromptSubmit", session: "old")
        send("PermissionRequest", session: "asking")
        send("UserPromptSubmit", session: "new")
        #expect(model.rows.map(\.id) == ["asking", "new", "old"])
        #expect(model.lead?.id == "asking")
    }

    @Test func desktopPlaceIsKept() {
        send("UserPromptSubmit", extra: [Place.key: ["conversation": "local_1"]])
        #expect(model.sessions.first?.place.conversation == "local_1")
    }

    @Test func clickingDoneRowClearsIt() {
        send("Stop")
        model.open(model.sessions[0])
        #expect(model.sessions.isEmpty)
    }

    @Test func clockText() {
        let now = Date()
        #expect(SessionRow.ago(now, now: now) == "now")
        #expect(SessionRow.ago(now.addingTimeInterval(-300), now: now) == "5m")
        #expect(SessionRow.ago(now.addingTimeInterval(-7200), now: now) == "2h")
    }
}
