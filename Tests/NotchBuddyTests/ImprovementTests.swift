import Foundation
import Testing
@testable import NotchBuddy

/// Always allow, the full command, tidying stuck rows and the low-usage warning.
struct AlwaysAllowTests {
    let rule: [String: Any] = ["type": "addRules", "behavior": "allow", "destination": "localSettings",
                               "rules": [["toolName": "Bash", "ruleContent": "npm test:*"]]]
    var event: [String: Any] {
        ["hook_event_name": "PermissionRequest", "tool_name": "Bash",
         "permission_suggestions": [rule, ["type": "setMode", "mode": "acceptEdits"]]]
    }

    @Test func alwaysHandsBackClaudesRule() throws {
        let data = try JSONSerialization.data(withJSONObject: event)
        let out = try #require(Permission.output(for: Data("always".utf8), event: data))
        let json = try #require(try JSONSerialization.jsonObject(with: out) as? [String: Any])
        let decision = try #require((json["hookSpecificOutput"] as? [String: Any])?["decision"] as? [String: Any])
        #expect(decision["behavior"] as? String == "allow")
        let rules = try #require(decision["updatedPermissions"] as? [[String: Any]])
        #expect(rules.count == 1)   // only the "allow" rule, not the mode change
        #expect(rules.first?["destination"] as? String == "localSettings")
    }

    @Test func alwaysWithNoSuggestionIsAPlainAllow() throws {
        let out = try #require(Permission.output(for: Data("always".utf8)))
        #expect(!String(decoding: out, as: UTF8.self).contains("updatedPermissions"))
    }

    @Test func alwaysText() {
        #expect(Permission.alwaysText(event) == "Bash(npm test:*)")
        #expect(Permission.alwaysText([:]) == nil)
    }

    @Test func detail() {
        #expect(Permission.detail(tool: "Bash", input: ["command": "rm -rf build && npm test"]) == "rm -rf build && npm test")
        #expect(Permission.detail(tool: "Edit", input: ["file_path": "/a/b/README.md"]) == "/a/b/README.md")
        #expect(Permission.detail(tool: "mcp__x__y", input: ["a": 1]) == #"{"a":1}"#)
        #expect(Permission.detail(tool: "mcp__x__y", input: [:]) == nil)
    }
}

@MainActor
struct TidyAndUsageTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        return m
    }()

    func send(_ name: String, session: String, pid: String? = nil, extra: [String: Any] = [:]) {
        var e: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/x/\(session)",
                                "tool_name": "Bash", "tool_input": ["command": "npm test"]]
        if let pid { e[Place.key] = ["pid": pid] }
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func rowsOfQuitClaudesAreRemoved() {
        send("UserPromptSubmit", session: "gone", pid: "111")
        send("UserPromptSubmit", session: "alive", pid: "222")
        model.tidy(isRunning: { $0 == 222 })
        #expect(model.sessions.map(\.id) == ["alive"])
    }

    @Test func silentWorkingRowsBecomeReady() {
        send("UserPromptSubmit", session: "a")
        model.tidy(now: Date() + 10 * 60, isRunning: { _ in true })
        #expect(model.sessions.first?.state == .working)
        model.tidy(now: Date() + 31 * 60, isRunning: { _ in true })
        #expect(model.sessions.first?.state == .ready)
    }

    @Test func permissionRowKeepsTheFullCommand() {
        send("PermissionRequest", session: "a", extra: [
            "tool_input": ["command": "npm test\nnpm run build"],
            "permission_suggestions": [["type": "addRules", "behavior": "allow",
                                        "rules": [["toolName": "Bash", "ruleContent": "npm test:*"]]]],
        ])
        let row = model.sessions.first
        #expect(row?.summary == "Run: npm test")
        #expect(row?.detail == "npm test\nnpm run build")
        #expect(row?.always == "Bash(npm test:*)")
    }

    @Test func hoverLines() {
        var s = Session(id: "a", folder: "/x", state: .waiting, color: Prefs.clay)
        #expect(s.hoverLines == 0)
        s.detail = String(repeating: "x", count: 130)          // wraps to 3 lines
        #expect(s.hoverLines == 3)
        s.always = "Bash(x:*)"; s.canAnswer = true
        #expect(s.hoverLines == 4)
        s.detail = Array(repeating: "x", count: 20).joined(separator: "\n")
        #expect(s.hoverLines == 7)                              // 6 at most, plus the always line
    }

    @Test func eachRowKeepsItsOwnContext() {
        send("UserPromptSubmit", session: "a")
        send("UserPromptSubmit", session: "b")
        let e: [String: Any] = ["hook_event_name": Usage.event, "session_id": "a", "context_used": 53.4]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
        #expect(model.sessions.first { $0.id == "a" }?.context == 53)
        #expect(model.sessions.first { $0.id == "b" }?.context == nil)
        // A status line for a conversation we have no row for doesn't add one.
        let other: [String: Any] = ["hook_event_name": Usage.event, "session_id": "zzz", "context_used": 10.0]
        model.handle(try! JSONSerialization.data(withJSONObject: other))
        #expect(model.sessions.count == 2)
    }

    @Test func statusLineWinsOverTheLog() {
        send("UserPromptSubmit", session: "a", extra: [ConversationSize.key: 40])
        #expect(model.sessions.first?.context == 40)
        let e: [String: Any] = ["hook_event_name": Usage.event, "session_id": "a", "context_used": 61.0]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
        send("PostToolUse", session: "a", extra: [ConversationSize.key: 45])
        #expect(model.sessions.first?.context == 61)
    }

    @Test func clawdSweatsWhenUsageIsLow() {
        let usage: [String: Any] = ["hook_event_name": Usage.event, "used_percentage": 95.0,
                                    "resets_at": Date().timeIntervalSince1970 + 3600]
        model.handle(try! JSONSerialization.data(withJSONObject: usage))
        #expect(model.usageIsLow)
        #expect(model.clawdMode == "low")
        send("PermissionRequest", session: "a")
        #expect(model.clawdMode == "waiting")                   // needing you still comes first
    }
}

/// Conversation size, read from a conversation's log.
struct ConversationSizeTests {
    func log(_ lines: [[String: Any]]) throws -> String {
        let path = FileManager.default.temporaryDirectory.appending(path: "nb-\(UUID()).jsonl").path
        let text = try lines.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
        try (text.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    func reply(_ cached: Int, sidechain: Bool = false) -> [String: Any] {
        ["type": "assistant", "isSidechain": sidechain,
         "message": ["model": "claude-x", "usage": ["input_tokens": 2, "cache_read_input_tokens": cached, "output_tokens": 98]]]
    }

    @Test func latestReplyCounts() throws {
        let path = try log([reply(1000), reply(200_000), ["type": "user", "message": ["content": "hi"]],
                            reply(5, sidechain: true)])
        #expect(ConversationSize.latest(inLog: path)?.tokens == 200_100)
        #expect(ConversationSize.latest(inLog: path)?.model == "claude-x")
        #expect(ConversationSize.latest(inLog: "/no/such/file") == nil)
    }

    @Test func percentOfTheCompactLimit() throws {
        let perModel: [String: Any] = ["modelSettings": ["claude-x": ["autoCompactWindow": 400_000]]]
        #expect(ConversationSize.limit(perModel, model: "claude-x", tokens: 10) == 400_000)
        #expect(ConversationSize.limit(perModel, model: "claude-y", tokens: 10) == 200_000)
        #expect(ConversationSize.limit(["autoCompactWindow": 300_000], model: "claude-y", tokens: 10) == 300_000)
        #expect(ConversationSize.limit([:], model: nil, tokens: 250_000) == 1_000_000)
        #expect(ConversationSize.percent(tokens: 213_800, limit: 400_000) == 53)
        #expect(ConversationSize.percent(tokens: 900_000, limit: 400_000) == 100)
    }

    @Test func helperAddsItToTheEvent() throws {
        let path = try log([reply(199_900)])
        let settings = FileManager.default.temporaryDirectory.appending(path: "nb-\(UUID()).json")
        try Data(#"{"modelSettings":{"claude-x":{"autoCompactWindow":400000}}}"#.utf8).write(to: settings)
        let event = try JSONSerialization.data(withJSONObject: ["session_id": "a", "transcript_path": path])
        let out = try #require(try JSONSerialization.jsonObject(with: ConversationSize.adding(to: event, settings: settings)) as? [String: Any])
        #expect(out[ConversationSize.key] as? Int == 50)
    }
}

/// Nothing running: what Clawd does depends on the time of day.
struct AllCaughtUpTests {
    @Test func timeOfDay() {
        #expect(DayPart(hour: 7) == .morning)
        #expect(DayPart(hour: 10) == .day)
        #expect(DayPart(hour: 22) == .day)
        #expect(DayPart(hour: 23) == .night)
        #expect(DayPart(hour: 3) == .night)
        #expect(DayPart(hour: 5) == .morning)
        #expect(DayPart.morning.clawdMode == "morning")
        #expect(DayPart.night.line.contains("off to bed"))
    }

    @Test func statusFollowsWhatHeIsDoing() {
        #expect(DayPart.day.line(for: "fish").contains("Gone fishing"))
        #expect(DayPart.morning.line(for: "fish").contains("Gone fishing"))   // hobbies in the morning too
        #expect(DayPart.day.line(for: nil) == DayPart.day.line)
        #expect(DayPart.day.line(for: "unknown") == DayPart.day.line)
        for mode in DayPart.restingModes where mode != "life" { #expect(DayPart.status[mode == "morning" ? "coffee" : "nightcap"] != nil) }
    }
}

/// Working time, naps, peek and outfits.
@MainActor
struct FunTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        return m
    }()

    func send(_ name: String, session: String = "a") {
        let e: [String: Any] = ["session_id": session, "hook_event_name": name, "cwd": "/x/\(session)", "tool_name": "Bash",
                                "tool_input": ["command": "npm test"]]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func usage(_ used: Double, resetsIn: Double = 3600) {
        let e: [String: Any] = ["hook_event_name": Usage.event, "used_percentage": used,
                                "resets_at": Date().timeIntervalSince1970 + resetsIn]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func workingTimeLastsThroughWaitingForYou() throws {
        send("UserPromptSubmit")
        let started = try #require(model.sessions.first?.workingSince)
        send("PermissionRequest")
        send("PostToolUse")
        #expect(model.sessions.first?.workingSince == started)
        send("Stop")
        #expect(model.sessions.first?.workingSince == nil)
    }

    @Test func elapsedText() {
        let now = Date()
        #expect(SessionRow.elapsed(now - 42, now: now) == "42s")
        #expect(SessionRow.elapsed(now - 12 * 60 - 5, now: now) == "12m")
        #expect(SessionRow.elapsed(now - 3900, now: now) == "1h 05m")
    }

    @Test func clawdNapsWhenUsageRunsOut() {
        UserDefaults.standard.removeObject(forKey: "rightSide")
        usage(100)
        #expect(model.usageOut)
        #expect(model.clawdMode == "out")
        #expect(model.rightText?.hasPrefix("Back at ") == true)
        // The window resets: he wakes up.
        model.tidy(now: Date() + 3601, isRunning: { _ in true })
        #expect(!model.usageOut)
        #expect(model.clawdMode != "out")
    }

    @Test func peeksOnlyForRealSessions() {
        var peeks = 0
        model.onPeek = { peeks += 1 }
        send("PermissionRequest")
        send("Notification")          // still needs you: no second peek
        #expect(peeks == 1)
        send("PermissionRequest", session: NotchModel.exampleID)
        #expect(peeks == 1)
    }

    @Test func outfits() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        func day(_ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12))! }
        #expect(Outfit.today(day(12, 5), calendar: calendar) == "santa")
        #expect(Outfit.today(day(12, 31), calendar: calendar) == "party")
        #expect(Outfit.today(day(1, 1), calendar: calendar) == "party")
        #expect(Outfit.today(day(10, 30), calendar: calendar) == "witch")
        #expect(Outfit.today(day(10, 2), calendar: calendar) == nil)
        #expect(Outfit.today(day(11, 24), calendar: calendar) == nil)
    }
}

struct ScreenChoiceTests {
    @Test func macBookScreenWins() {
        #expect(NotchGeometry.pick([false, true], external: false) == 1)
    }

    @Test func externalWhenChosenAndPluggedIn() {
        #expect(NotchGeometry.pick([true, false], external: true) == 1)
        #expect(NotchGeometry.pick([false, true], external: true) == 0)
    }

    @Test func fallsBackWhenTheChosenKindIsMissing() {
        #expect(NotchGeometry.pick([true], external: true) == 0)        // MacBook alone
        #expect(NotchGeometry.pick([false, false], external: false) == 0) // lid closed
        #expect(NotchGeometry.pick([], external: false) == nil)
    }
}

struct SoundChoiceTests {
    func fresh() -> UserDefaults {
        let d = UserDefaults(suiteName: "sound-test-\(UUID())")!
        Prefs.register(d)
        return d
    }

    @Test func oldSwitchesKeepTheirSounds() {
        let d = fresh()
        #expect(Prefs.sound(for: .needsYou, d) == "Ping")
        #expect(Prefs.sound(for: .finished, d) == Prefs.silent)   // was off
        #expect(Prefs.sound(for: .usageLow, d) == "Purr")
        d.set(false, forKey: "soundNeedsYou")
        #expect(Prefs.sound(for: .needsYou, d) == Prefs.silent)
    }

    @Test func aPickedSoundWins() {
        let d = fresh()
        d.set("Hero", forKey: Prefs.Moment.finished.key)
        d.set(Prefs.silent, forKey: Prefs.Moment.needsYou.key)
        #expect(Prefs.sound(for: .finished, d) == "Hero")
        #expect(Prefs.sound(for: .needsYou, d) == Prefs.silent)
    }

    @Test func offersTheMacsSounds() {
        #expect(Prefs.sounds.contains("Glass"))
        #expect(Prefs.sounds == Prefs.sounds.sorted())
    }
}

/// What Claude is doing, and which model.
@MainActor
struct ActivityAndModelTests {
    let model = NotchModel()
    init() { model.live = false }

    func send(_ name: String, tool: String? = nil, input: [String: Any] = [:], extra: [String: Any] = [:]) {
        var e: [String: Any] = ["hook_event_name": name, "session_id": "a", "cwd": "/x/app", "tool_input": input]
        if let tool { e["tool_name"] = tool }
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func plainWords() {
        #expect(Activity.line(tool: "Edit", input: ["file_path": "/a/NotchView.swift"]) == "Editing NotchView.swift")
        #expect(Activity.line(tool: "Bash", input: ["command": "swift test", "description": "Run the tests"]) == "Run the tests")
        #expect(Activity.line(tool: "Bash", input: ["command": "swift build\necho hi"]) == "Running swift build")
        #expect(Activity.line(tool: "WebFetch", input: ["url": "https://example.com/a"]) == "Reading example.com")
        #expect(Activity.line(tool: "mcp__browser__take_screenshot", input: [:]) == "Using take screenshot")
    }

    @Test func keptBetweenToolsAndClearedAtTheEnd() {
        send("PreToolUse", tool: "Read", input: ["file_path": "/a/b.swift"])
        #expect(model.sessions.first?.activity == "Reading b.swift")
        send("PostToolUse", tool: "Read")
        #expect(model.sessions.first?.activity == "Reading b.swift")
        send("Stop")
        #expect(model.sessions.first?.activity == nil)
    }

    @Test func shortModelNames() {
        #expect(ModelName.short("claude-opus-5-5") == "Opus 5.5")
        #expect(ModelName.short("claude-sonnet-4-5-20250929[1m]") == "Sonnet 4.5")
        #expect(ModelName.short("claude-opus-4-20250514") == "Opus 4")
        #expect(ModelName.short("claude-3-5-haiku-20241022") == "Haiku 3.5")
        #expect(ModelName.short("<synthetic>") == nil)
    }

    @Test func rowKnowsItsModel() {
        send("UserPromptSubmit", extra: [ModelName.key: "claude-fable-5-2"])
        #expect(model.sessions.first?.model == "Fable 5.2")
        send("PostToolUse")   // no model this time: keeps the one it had
        #expect(model.sessions.first?.model == "Fable 5.2")
    }
}

/// The name you gave a conversation.
@MainActor
struct SessionNameTests {
    let model: NotchModel = { let m = NotchModel(); m.live = false; return m }()

    func send(_ name: String, extra: [String: Any] = [:]) {
        var e: [String: Any] = ["hook_event_name": name, "session_id": "a", "cwd": "/x/Developer"]
        e.merge(extra) { $1 }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    @Test func newestNameInTheLogWins() throws {
        let path = NSTemporaryDirectory() + "title-\(UUID()).jsonl"
        let lines = [#"{"type":"custom-title","customTitle":"Old name","sessionId":"a"}"#,
                     #"{"type":"user","message":{"content":"custom-title"}}"#,
                     #"{"type":"custom-title","customTitle":"app build","sessionId":"a"}"#,
                     #"{"type":"assistant","message":{"usage":{"input_tokens":5}}}"#]
        try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        #expect(ConversationSize.title(in: ConversationSize.tail(ofLog: path)) == "app build")
        #expect(ConversationSize.title(in: []) == nil)
    }

    @Test func rowUsesTheNameAndKeepsIt() {
        send("UserPromptSubmit")
        #expect(model.sessions.first?.name == "Developer")          // no name yet: the folder
        send("PostToolUse", extra: [ConversationSize.titleKey: "app build"])
        #expect(model.sessions.first?.name == "app build")
        send("Stop")                                                // the next event without one keeps it
        #expect(model.sessions.first?.name == "app build")
    }
}
