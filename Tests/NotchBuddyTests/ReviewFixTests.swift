import Darwin
import Foundation
import Testing
@testable import NotchBuddy

/// Which sessions get a row: busy ones always, idle ones only when they're worth showing.
@MainActor
struct IdleRowTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        m.hideIdle = false
        return m
    }()

    func send(_ name: String, session: String = "s1", tool: String = "Bash", extra: [String: Any] = [:]) {
        var e: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/Users/me/\(session)",
                                "tool_name": tool, "tool_input": ["command": "npm test"]]
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func aNewSessionShowsReady() {
        send("SessionStart", extra: ["source": "startup"])
        #expect(model.sessions.map(\.state) == [.ready])
    }

    /// The desktop app reopens every conversation when it launches. None of them is doing anything.
    @Test func reopenedSessionsGetNoRowUntilTheyWork() {
        for id in ["a", "b", "c"] { send("SessionStart", session: id, extra: ["source": "resume"]) }
        #expect(model.sessions.isEmpty)
        #expect(model.clawdMode != "working")
        let color = model.all.first { $0.id == "b" }?.color
        send("UserPromptSubmit", session: "b")
        #expect(model.sessions.map(\.id) == ["b"])
        #expect(model.sessions.first?.color == color)
    }

    @Test func hidingFinishedSessionsHidesEveryIdleOne() {
        model.hideIdle = true
        send("SessionStart", session: "new", extra: ["source": "startup"])
        send("UserPromptSubmit", session: "busy")
        send("UserPromptSubmit", session: "finished")
        send("Stop", session: "finished")
        #expect(model.sessions.map(\.id) == ["busy"])
        model.hideIdle = false   // "Stay until I click": they're back
        #expect(Set(model.sessions.map(\.id)) == ["new", "busy", "finished"])
    }

    /// A minute after a turn ends, Claude says it's waiting for your input. That isn't "needs you".
    @Test func aHiddenFinishedSessionStaysHidden() {
        model.hideIdle = true
        var peeks = 0
        model.onPeek = { peeks += 1 }
        send("UserPromptSubmit")
        send("PostToolUse", extra: ["tool_name": "Edit", "tool_input": ["file_path": "/a.swift", "old_string": "a", "new_string": "b\nc"]])
        send("Stop")
        send("Notification", extra: ["notification_type": "idle_prompt", "message": "Claude is waiting for your input"])
        #expect(model.sessions.isEmpty)
        #expect(model.all.first?.state == .done)
        #expect(peeks == 0)
        // Its next turn is the same session: same colour, and what it did before still counts.
        let color = model.all.first?.color
        send("UserPromptSubmit")
        #expect(model.sessions.first?.color == color)
        #expect(model.sessions.first?.work.added == 2)
    }

    @Test func notificationsFromSessionsWeDontKnow() {
        send("Notification", session: "idle", extra: ["notification_type": "idle_prompt"])
        send("Notification", session: "login", extra: ["notification_type": "auth_success"])
        #expect(model.all.isEmpty)
        send("Notification", session: "asks", extra: ["notification_type": "permission_prompt"])
        #expect(model.sessions.map(\.state) == [.waiting])
    }

    @Test func onlySomeNotificationsNeedYou() {
        send("UserPromptSubmit")
        for kind in ["auth_success", "agent_completed", "elicitation_complete", "quota_auto_resume_fired", "plugin_notification"] {
            send("Notification", extra: ["notification_type": kind])
            #expect(model.sessions.first?.state == .working, "\(kind)")
        }
        send("Notification", extra: ["notification_type": "elicitation_dialog"])
        #expect(model.sessions.first?.state == .waiting)
    }

    /// Stopped with Esc: no "done" comes, but a minute later Claude says it's idle.
    @Test func idleWhileWeThoughtItWorkedMeansItStopped() {
        send("UserPromptSubmit")
        send("Notification", extra: ["notification_type": "idle_prompt"])
        #expect(model.sessions.first?.state == .ready)
    }

    @Test func olderClaudesNotificationsGoByTheirWords() {
        #expect(NotchModel.nudge(["message": "Claude is waiting for your input"]) == .idle)
        #expect(NotchModel.nudge(["message": "Claude needs your permission to use Bash"]) == .needsYou)
    }

    @Test func clearingARowKeepsTheSession() {
        send("UserPromptSubmit")
        model.clear(model.sessions[0])
        #expect(model.sessions.isEmpty)
        #expect(model.all.count == 1)
        send("PreToolUse")
        #expect(model.sessions.first?.state == .working)
    }

    @Test func hiddenSessionsAreForgottenAfterHalfADay() {
        send("SessionStart", extra: ["source": "resume"])
        model.tidy(now: Date() + 3600, isRunning: { _ in true })
        #expect(model.all.count == 1)
        model.tidy(now: Date() + 13 * 3600, isRunning: { _ in true })
        #expect(model.all.isEmpty)
    }

    @Test func aFinishedRowYouKeepIsNotForgotten() {
        send("UserPromptSubmit")
        send("Stop")
        model.tidy(now: Date() + 13 * 3600, isRunning: { _ in true })
        #expect(model.sessions.map(\.state) == [.done])
    }
}

/// A request stays open while other tools come and go.
@MainActor
struct OpenRequestTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        m.hideIdle = false
        return m
    }()

    func event(_ name: String, tool: String = "Bash", input: [String: Any] = ["command": "npm test"]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["session_id": "s1", "hook_event_name": name, "cwd": "/Users/me/shop",
                                                     "tool_name": tool, "tool_input": input])
    }

    /// A line to a pretend helper that is still waiting.
    func line() -> (reply: Reply, helper: Int32) {
        var fds: [Int32] = [0, 0]
        socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
        return (Reply(fd: fds[0], onGone: { _ in }), fds[1])
    }

    @Test func otherToolsDontAnswerIt() {
        let (reply, helper) = line()
        defer { close(helper) }
        model.handle(event("PreToolUse"))
        model.handle(event("PermissionRequest"), reply: reply)
        // Claude reads a file at the same time, and a helper of its own runs a search.
        model.handle(event("PreToolUse", tool: "Read", input: ["file_path": "/a.swift"]))
        model.handle(event("PostToolUse", tool: "Read", input: ["file_path": "/a.swift"]))
        model.handle(event("PostToolUse", tool: "Bash", input: ["command": "ls"]))
        #expect(model.sessions.first?.state == .waiting)
        #expect(model.sessions.first?.summary == "Run: npm test")
        #expect(model.sessions.first?.canAnswer == true)
        #expect(model.sessions.first?.work.lastCommand == "ls")
        // The asked step ran: it was allowed somewhere else.
        model.handle(event("PostToolUse"))
        #expect(model.sessions.first?.state == .working)
        #expect(model.sessions.first?.canAnswer == false)
    }

    @Test func onceTheHelperHasGoneTheNextStepAnswersIt() {
        let (reply, helper) = line()
        defer { close(helper) }
        model.handle(event("PermissionRequest"), reply: reply)
        model.replyGone(reply)
        model.handle(event("PreToolUse", tool: "Read", input: ["file_path": "/a.swift"]))
        #expect(model.sessions.first?.state == .working)
    }

    @Test func theEndOfTheTurnAlwaysClosesIt() {
        let (reply, helper) = line()
        defer { close(helper) }
        model.handle(event("PermissionRequest"), reply: reply)
        model.handle(event("Stop"))
        #expect(model.sessions.first?.state == .done)
        #expect(model.sessions.first?.canAnswer == false)
    }
}

/// Account names follow where each account is logged in now, not where we first heard of it.
@MainActor
@Suite(.serialized)
struct AccountNameTests {
    let model: NotchModel = {
        UserDefaults.standard.removeObject(forKey: "accounts")
        let m = NotchModel()
        m.live = false
        return m
    }()

    func usage(_ org: String, from: String, weekOnly: Bool = false, resetsIn: Double = 3600) {
        var e: [String: Any] = [Account.key: org, "from": from, "week_used": 10.0,
                                "week_resets": Date().timeIntervalSince1970 + resetsIn]
        if !weekOnly { e["used_percentage"] = 20.0; e["resets_at"] = Date().timeIntervalSince1970 + resetsIn }
        model.takeUsage(e)
    }

    func name(_ org: String) -> String? { model.accounts.first { $0.id == org }?.name }

    @Test func namesFollowASwapOfAccounts() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        // First heard: work in the Terminal, home in the desktop app.
        usage("work", from: "Terminal login")
        usage("home", from: "Desktop app")
        #expect(name("work") == "Terminal")
        #expect(name("home") == "Desktop")
        // Since then you've logged in the other way round.
        model.terminalOrg = "home"
        let event: [String: Any] = ["hook_event_name": "UserPromptSubmit", "session_id": "a", "cwd": "/x/a",
                                    Account.key: "work", Place.key: ["conversation": "local_1"]]
        model.handle(try! JSONSerialization.data(withJSONObject: event))
        #expect(name("home") == "Terminal")
        #expect(name("work") == "Desktop")
        #expect(model.account(of: model.sessions[0])?.name == "Desktop")
    }

    @Test func anAccountInBothPlacesIsNamedForNeither() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        usage("home", from: "Terminal login")
        model.terminalOrg = "home"
        model.desktopOrg = "home"
        #expect(name("home") == "Claude")
    }

    @Test func accountsKnowTheirEmailAddress() throws {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        // The Terminal's settings file names its login.
        let file = FileManager.default.temporaryDirectory.appending(path: "claude-\(UUID()).json")
        try Data(#"{"oauthAccount": {"organizationUuid": "home", "emailAddress": "me@home.com"}}"#.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let login = try #require(Account.terminalLogin(file: file))
        model.terminalOrg = login.org
        model.noteEmail(login.email, for: login.org)   // heard before the account has any usage
        usage("home", from: "Terminal login")
        #expect(model.accounts.first?.email == "me@home.com")
        #expect(AccountRow.where(model.accounts[0]) == "Terminal login \u{00B7} me@home.com")
        #expect(model.accounts[0].summary.hasPrefix("me@home.com"))

        // A desktop app session says who it's logged in as.
        usage("work", from: "Desktop app")
        let tagged = Account.addingOrg(to: Data(#"{"hook_event_name":"UserPromptSubmit","session_id":"a","cwd":"/x/a"}"#.utf8),
                                       environment: ["CLAUDE_CODE_ORGANIZATION_UUID": "work", "CLAUDE_CODE_USER_EMAIL": "me@work.com"])
        model.handle(tagged)
        #expect(model.accounts.first { $0.id == "work" }?.email == "me@work.com")
        // Saved with the account, so it's there after a restart.
        #expect(Account.load().first { $0.id == "work" }?.email == "me@work.com")
    }

    @Test func renamingAnAccount() {
        let account = Account(id: "work", from: "Desktop app")
        #expect(AccountRow.custom("  Metalab ", for: account) == "Metalab")
        #expect(AccountRow.custom("", for: account) == nil)          // emptied: back to "Desktop"
        #expect(AccountRow.custom("Desktop", for: account) == nil)   // the short name isn't a name of your own
    }

    @Test func lastWeeksFigureDoesntKeepAnAccountAround() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        model.terminalOrg = "home"
        usage("home", from: "Terminal login")
        usage("old", from: "Desktop app", weekOnly: true, resetsIn: 60)
        model.desktopOrg = "work"   // the desktop app is on another account now
        #expect(model.severalAccounts)
        model.tidy(now: Date() + 120, isRunning: { _ in true })
        #expect(!model.severalAccounts)
        #expect(model.accounts.map(\.id) == ["home"])
    }
}
