import Foundation
import Testing
@testable import NotchBuddy

/// What the helper prints back to Claude, and that it prints nothing whenever something is off.
struct PermissionTests {
    static func event(_ name: String, tool: String = "Bash", input: [String: Any] = ["command": "npm test"],
                      session: String = "s1") -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "session_id": session, "hook_event_name": name, "cwd": "/Users/me/shop",
            "tool_name": tool, "tool_input": input,
        ])
    }

    func decision(_ output: Data?) throws -> [String: Any] {
        let data = try #require(output)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let specific = try #require(json["hookSpecificOutput"] as? [String: Any])
        #expect(specific["hookEventName"] as? String == "PermissionRequest")
        return try #require(specific["decision"] as? [String: Any])
    }

    @Test func allowFormat() throws {
        let d = try decision(Permission.output(for: Data("allow".utf8)))
        #expect(d["behavior"] as? String == "allow")
        #expect(d.count == 1)
    }

    @Test func denyFormat() throws {
        let d = try decision(Permission.output(for: Data("deny".utf8)))
        #expect(d["behavior"] as? String == "deny")
        #expect(d["message"] is String)
    }

    @Test func anythingElsePrintsNothing() {
        for reply in ["", "yes", "ALLOW", "allow\n", "{}"] {
            #expect(Permission.output(for: Data(reply.utf8)) == nil)
        }
    }

    @Test func onlyPermissionRequestsWait() {
        #expect(Permission.wantsAnswer(Self.event("PermissionRequest")))
        #expect(!Permission.wantsAnswer(Self.event("PreToolUse")))
        #expect(!Permission.wantsAnswer(Self.event("PermissionRequest", tool: "AskUserQuestion")))
        #expect(!Permission.wantsAnswer(Data("not json".utf8)))
    }

    @Test func summaries() {
        #expect(Permission.summary(tool: "Bash", input: ["command": "npm test\nnpm run lint"]) == "Run: npm test")
        #expect(Permission.summary(tool: "Edit", input: ["file_path": "/a/b/README.md"]) == "Edit: README.md")
        #expect(Permission.summary(tool: "Write", input: ["file_path": "/a/notes.txt"]) == "Write: notes.txt")
        #expect(Permission.summary(tool: "WebFetch", input: ["url": "https://example.com/x"]) == "Open: example.com")
        #expect(Permission.summary(tool: "mcp__files__delete_file", input: [:]) == "Use: delete_file")
        #expect(Permission.summary(tool: "Bash", input: [:]) == "Run")
    }

    @Test func helperHookTimeoutIsLongerThanItsWait() {
        #expect(Double(Permission.hookTimeout) > Permission.wait)
    }
}

/// The helper and the app talking over a real socket in a temporary folder.
struct HelperTests {
    let path = FileManager.default.temporaryDirectory
        .appending(path: "nb-\(UUID().uuidString.prefix(8)).sock").path
    let request = PermissionTests.event("PermissionRequest")

    @Test func noAppMeansNoAnswer() {
        let start = Date()
        #expect(HookHelper.send(request, to: path, wait: 5) == nil)
        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test func appAnswersAllow() throws {
        let listener = EventListener(path: path, onEvent: { _, reply in reply?.send("allow") })
        let reply = try #require(HookHelper.send(request, to: path, wait: 5))
        #expect(Permission.output(for: reply) != nil)
        _ = listener
    }

    @Test func appHangsUpMeansNoAnswer() {
        let listener = EventListener(path: path, onEvent: { _, reply in reply?.cancel() })
        #expect(HookHelper.send(request, to: path, wait: 5) == nil)
        _ = listener
    }

    @Test func slowAppMeansNoAnswer() {
        let kept = Box()
        let listener = EventListener(path: path, onEvent: { _, reply in kept.reply = reply })   // never answers
        let start = Date()
        #expect(HookHelper.send(request, to: path, wait: 0.5) == nil)
        #expect(Date().timeIntervalSince(start) < 2)
        _ = listener
    }

    @Test func appNoticesWhenTheHelperGivesUp() async throws {
        let kept = Box(), gone = Box()
        let listener = EventListener(path: path, onEvent: { _, reply in kept.reply = reply },
                                     onGone: { gone.reply = $0 })
        _ = HookHelper.send(request, to: path, wait: 0.2)
        try await Task.sleep(for: .milliseconds(300))
        #expect(gone.reply != nil && gone.reply === kept.reply)
        _ = listener
    }

    @Test func otherEventsGetNoLineBack() {
        let saw = Box()
        let listener = EventListener(path: path, onEvent: { _, reply in saw.sawReply = reply != nil })
        #expect(HookHelper.send(PermissionTests.event("PreToolUse"), to: path, wait: nil) == nil)
        Thread.sleep(forTimeInterval: 0.2)
        #expect(saw.sawReply == false)
        _ = listener
    }

    @Test func helperAddsWhereTheSessionLives() throws {
        let env = ["CLAUDE_CODE_ENTRYPOINT": "claude-desktop", "CLAUDE_CODE_HOST_SESSION_ID": "local_abc",
                   "__CFBundleIdentifier": "app.id", "TERM_PROGRAM": "vscode"]
        let data = Place.addingHere(to: request, environment: env)
        let event = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let place = Place(event: event)
        #expect(place.conversation == "local_abc")
        #expect(place.app == "app.id")
        #expect(place.terminal == "vscode")
        #expect(place.folder == "/Users/me/shop")
        // Outside the desktop app, no conversation id is taken.
        let cli = Place.addingHere(to: request, environment: ["CLAUDE_CODE_HOST_SESSION_ID": "local_abc"])
        #expect(Place(event: try #require(try JSONSerialization.jsonObject(with: cli) as? [String: Any])).conversation == nil)
    }

    @Test func brokenEventIsPassedOnUnchanged() {
        let junk = Data("not json".utf8)
        #expect(Place.addingHere(to: junk) == junk)
    }
}

final class Box: @unchecked Sendable {
    var reply: Reply?
    var sawReply: Bool?
}
