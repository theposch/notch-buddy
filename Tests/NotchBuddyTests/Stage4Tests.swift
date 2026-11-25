import Foundation
import Testing
@testable import NotchBuddy

/// The status line, usage left, the right-side options and the update check.
struct StatusLineTests {
    let input = try! JSONSerialization.data(withJSONObject: [
        "model": ["display_name": "Opus"],
        "context_window": ["used_percentage": 12.4],
        "rate_limits": ["five_hour": ["used_percentage": 38.0, "resets_at": 1_900_000_000]],
    ])

    @Test func usageIsPassedToTheApp() throws {
        let event = try #require(StatusLine.event(from: input))
        let json = try #require(try JSONSerialization.jsonObject(with: event) as? [String: Any])
        #expect(json["hook_event_name"] as? String == Usage.event)
        #expect(json["used_percentage"] as? Double == 38)
    }

    @Test func contextIsPassedWithItsSession() throws {
        let input = Data(#"{"session_id":"s1","context_window":{"used_percentage":53.2}}"#.utf8)
        let event = try #require(StatusLine.event(from: input))
        let json = try #require(try JSONSerialization.jsonObject(with: event) as? [String: Any])
        #expect(json["session_id"] as? String == "s1")
        #expect(json["context_used"] as? Double == 53.2)
        #expect(json["used_percentage"] == nil)
    }

    @Test func noUsageNoEvent() {
        #expect(StatusLine.event(from: Data(#"{"model":{"display_name":"Opus"}}"#.utf8)) == nil)
        #expect(StatusLine.event(from: Data("junk".utf8)) == nil)
    }

    @Test func ownLine() {
        #expect(StatusLine.ownLine(from: input) == "Opus · 12% context")
        #expect(StatusLine.ownLine(from: Data("{}".utf8)) == nil)
    }

    @Test func usageLeft() {
        let now = Date()
        #expect(Usage(used: 38, resets: now + 60).left(at: now) == 62)
        #expect(Usage(used: 38, resets: now - 60).left(at: now) == nil)   // window has reset
        #expect(Usage(used: 120, resets: now + 60).left(at: now) == 0)
    }
}

struct StatusLineSettingTests {
    let hook = HookSettings.command(for: "/Apps/Notch Buddy.app/Contents/MacOS/NotchBuddy")

    @Test func wrapsAndRestoresAnEarlierStatusLine() throws {
        let theirs: [String: Any] = ["type": "command", "command": "~/bin/my-line.sh", "padding": 2]
        let added = HookSettings.adding(to: ["statusLine": theirs], command: hook)
        let ours = try #require(added["statusLine"] as? [String: Any])
        let command = try #require(ours["command"] as? String)
        #expect(command.hasPrefix(String(hook.dropLast(4)) + "statusline "))
        #expect(ours["padding"] as? Int == 2)
        #expect(HookSettings.previousStatusLine(command)?["command"] as? String == "~/bin/my-line.sh")

        let removed = HookSettings.removing(from: added).settings
        #expect(NSDictionary(dictionary: removed["statusLine"] as? [String: Any] ?? [:]).isEqual(to: theirs))
    }

    @Test func withNoEarlierStatusLineRemoveLeavesNone() {
        let added = HookSettings.adding(to: [:], command: hook)
        #expect((added["statusLine"] as? [String: Any])?["command"] as? String == String(hook.dropLast(4)) + "statusline")
        #expect(HookSettings.removing(from: added).settings["statusLine"] == nil)
    }

    @Test func connectingTwiceDoesNotWrapOurselves() throws {
        let theirs: [String: Any] = ["type": "command", "command": "echo hi"]
        let twice = HookSettings.adding(to: HookSettings.adding(to: ["statusLine": theirs], command: hook), command: hook)
        let command = try #require((twice["statusLine"] as? [String: Any])?["command"] as? String)
        #expect(HookSettings.previousStatusLine(command)?["command"] as? String == "echo hi")
    }

    @Test func someoneElsesStatusLineIsLeftAlone() {
        let theirs: [String: Any] = ["type": "command", "command": "echo hi"]
        #expect(!HookSettings.removing(from: ["statusLine": theirs]).changed)
    }
}

struct UpdaterTests {
    @Test func versions() {
        #expect(Updater.isNewer("0.10", than: "0.9"))
        #expect(Updater.isNewer("1.0", than: "0.9.9"))
        #expect(!Updater.isNewer("1.2", than: "1.2.0"))
        #expect(!Updater.isNewer("0.3", than: "0.4"))
    }

    @Test func releasePage() {
        let page = Data(#"{"tag_name":"v0.5","html_url":"https://example.com/releases/v0.5"}"#.utf8)
        #expect(Updater.newer(in: page, than: "0.4")?.version == "0.5")
        #expect(Updater.newer(in: page, than: "0.5") == nil)
        #expect(Updater.newer(in: Data("oops".utf8), than: "0.1") == nil)
    }
}

/// The right side of the closed notch, and the example.
@MainActor
@Suite(.serialized)
struct RightSideTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        return m
    }()

    init() { UserDefaults.standard.removeObject(forKey: "rightSide") }

    func send(_ name: String, session: String) {
        let e: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/x/\(session)", "tool_name": "Bash"]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func usage(_ used: Double) {
        let e: [String: Any] = ["hook_event_name": Usage.event, "used_percentage": used,
                                "resets_at": Date().timeIntervalSince1970 + 3600]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func with(_ side: Prefs.RightSide, _ body: () -> Void) {
        UserDefaults.standard.set(side.rawValue, forKey: "rightSide")
        body()
        UserDefaults.standard.removeObject(forKey: "rightSide")
    }

    @Test func autoAddsACountAndSaysNeedsYou() {
        send("UserPromptSubmit", session: "a")
        send("UserPromptSubmit", session: "b")
        model.clawdWord = "Moonwalking…"
        #expect(model.rightText == "Moonwalking… · 2")
        send("PermissionRequest", session: "a")
        #expect(model.rightText == "Needs you")
    }

    @Test func otherOptions() {
        usage(38)
        send("UserPromptSubmit", session: "a")
        model.clawdWord = "Pondering…"
        with(.word) { #expect(model.rightText == "Pondering…") }
        with(.sessions) { #expect(model.rightText == "1"); #expect(model.showsSpinner) }
        with(.usage) { #expect(model.rightText == "62%"); #expect(model.rightIsUsage) }
    }

    @Test func autoShowsUsageWhenNothingIsHappening() {
        usage(90)
        #expect(model.rightText == "10%")
    }

    @Test func exampleNeverTouchesRealSessions() async throws {
        send("UserPromptSubmit", session: "real")
        model.playExample()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.sessions.map(\.id).sorted() == [NotchModel.exampleID, "real"])
        // Events can't reach the example.
        send("Stop", session: NotchModel.exampleID)
        #expect(model.sessions.first { $0.id == NotchModel.exampleID }?.state == .working)
        #expect(model.sessions.first { $0.id == "real" }?.state == .working)
    }
}
