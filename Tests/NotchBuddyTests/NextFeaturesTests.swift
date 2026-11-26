import AppKit
import Foundation
import Testing
@testable import NotchBuddy

/// "At this pace you run out around 3:40."
struct UsageForecastTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func reading(_ minutesAgo: Double, _ used: Double) -> Usage.Reading { .init(at: now.addingTimeInterval(-minutesAgo * 60), used: used) }

    @Test func aFastPaceRunsOutBeforeTheReset() throws {
        // 30% in the last half hour, 60% used, three hours to go: 40% more takes 40 minutes.
        let out = try #require(Usage.runsOut(readings: [reading(30, 30), reading(15, 45)], used: 60, resets: now.addingTimeInterval(3 * 3600), now: now))
        #expect(abs(out.timeIntervalSince(now) - 40 * 60) < 1)
    }

    @Test func aSlowPaceLastsUntilTheReset() {
        // 5% in half an hour with an hour to go.
        #expect(Usage.runsOut(readings: [reading(30, 55)], used: 60, resets: now.addingTimeInterval(3600), now: now) == nil)
    }

    @Test func aPauseMeansNoWarning() {
        // Nothing used in the last 45 minutes: no pace to project.
        #expect(Usage.runsOut(readings: [reading(40, 60), reading(5, 60)], used: 60, resets: now.addingTimeInterval(3 * 3600), now: now) == nil)
    }

    /// With only a few minutes of readings, the window's average so far stands in.
    @Test func earlyOnTheWholeWindowsPaceStandsIn() throws {
        let resets = now.addingTimeInterval(3 * 3600)             // two hours into the window
        let out = try #require(Usage.runsOut(readings: [reading(3, 78)], used: 80, resets: resets, now: now))
        #expect(abs(out.timeIntervalSince(now) - 30 * 60) < 1)    // 80% in 2 hours: 20% more in 30 minutes
        // Ten minutes into a window is too early to say anything.
        #expect(Usage.runsOut(readings: [], used: 10, resets: now.addingTimeInterval(Usage.window - 600), now: now) == nil)
    }

    @Test func nothingToSayWhenItsUsedUpOrOver() {
        #expect(Usage.runsOut(readings: [reading(30, 50)], used: 100, resets: now.addingTimeInterval(3600), now: now) == nil)
        #expect(Usage.runsOut(readings: [reading(30, 50)], used: 80, resets: now.addingTimeInterval(-1), now: now) == nil)
    }

    @Test func anAccountRemembersThisWindowsReadingsOnly() {
        var account = Account(id: "a")
        let resets = now.addingTimeInterval(3 * 3600)
        account.take(Usage(used: 30, resets: resets), now: now.addingTimeInterval(-1800))
        account.take(Usage(used: 31, resets: resets), now: now.addingTimeInterval(-1790))   // seconds later: replaces the one before
        account.take(Usage(used: 60, resets: resets), now: now)
        #expect(account.readings?.map(\.used) == [31, 60])
        #expect(account.runsOut(now: now) != nil)
        #expect(account.paceText(now: now)?.hasPrefix("At this pace, out around ") == true)
        // A new window starts from scratch.
        account.take(Usage(used: 2, resets: resets.addingTimeInterval(Usage.window)), now: now.addingTimeInterval(4 * 3600))
        #expect(account.readings?.map(\.used) == [2])
    }
}

@MainActor
struct UsagePaceMessageTests {
    /// A model that starts with no accounts and leaves none behind for other tests.
    func freshModel() -> NotchModel {
        let model = NotchModel()
        model.live = false
        model.keepsAccounts = false
        model.forgetAccounts()
        return model
    }

    @Test func itSaysSoOnceAWindow() {
        let model = freshModel()
        #expect(Notice.Kind.important.contains(.usagePace))
        #expect(Notice.Kind.listed.contains(.usagePace))
        #expect(Notice(kind: .usagePace, word: "").animation == "sweat")
        // One reading, two hours into the window: the average pace gives the notch a label,
        // but a message waits until the pace has actually been watched.
        let resets = Date().addingTimeInterval(3 * 3600)
        model.takeUsage([Account.key: "a", "used_percentage": 50.0, "resets_at": resets.timeIntervalSince1970])
        #expect(model.shown == nil)
        #expect(model.accounts.first.flatMap { model.paceLabel($0) }?.hasPrefix("out ") == true)
        #expect(model.usageStripWidth(short: false) > NotchModel.usageRing + 6 + NotchModel.topWidth("50%"))

        // Fifteen minutes of fast use, watched: at this pace it's out in about 20 minutes.
        var fast = Account(id: "b")
        fast.take(Usage(used: 50, resets: resets), now: Date().addingTimeInterval(-15 * 60))
        fast.take(Usage(used: 70, resets: resets), now: Date())
        #expect(fast.runsOut(measuredOnly: true) != nil)
        model.takeUsage([Account.key: "c", "used_percentage": 10.0, "resets_at": resets.timeIntervalSince1970])
        #expect(model.shown == nil)   // a slow account: still nothing to say
    }

    @Test func aWatchedFastPacePostsTheMessage() {
        let model = freshModel()
        let now = Date(), resets = now.addingTimeInterval(3 * 3600)
        // Fifteen minutes of fast use, watched: at this pace it's out in about 20 minutes.
        model.takeUsage([Account.key: "pace-test", "used_percentage": 50.0, "resets_at": resets.timeIntervalSince1970], now: now.addingTimeInterval(-15 * 60))
        #expect(model.reaction == nil)
        model.takeUsage([Account.key: "pace-test", "used_percentage": 70.0, "resets_at": resets.timeIntervalSince1970], now: now)
        // Clawd reacts to it whichever messages you've switched on, so that's what this checks.
        let first = model.reaction
        #expect(first?.kind == .usagePace)
        #expect(first?.word.contains("ut by ") == true)       // "Out by 3:40 PM", or "Work out by …" with several accounts
        // Said once for this window.
        model.takeUsage([Account.key: "pace-test", "used_percentage": 72.0, "resets_at": resets.timeIntervalSince1970], now: now.addingTimeInterval(120))
        #expect(model.reaction?.id == first?.id)
    }
}

/// Clicking a row goes to its conversation, tab or pane, as closely as the app it runs in allows.
struct JumpTests {
    func place(_ info: [String: String], cwd: String = "/Users/me/shop") -> Place {
        Place(event: ["cwd": cwd, Place.key: info])
    }

    @Test func theClaudeAppOpensTheConversation() {
        let steps = place(["app": "com.anthropic.claudefordesktop", "conversation": "local_1"]).steps
        #expect(steps == [.open(URL(string: "claude://claude.ai/epitaxy/local_1")!)])
    }

    @Test func terminalAndITermBringTheTabForward() {
        #expect(place(["app": "com.apple.Terminal", "terminal": "Apple_Terminal", "tty": "/dev/ttys003"]).steps == [.tab(.terminal, tty: "/dev/ttys003")])
        #expect(place(["app": "com.googlecode.iterm2", "terminal": "iTerm.app", "tty": "/dev/ttys007"]).steps == [.tab(.iTerm, tty: "/dev/ttys007")])
        #expect(Place.tabScript(for: .iTerm).contains("tell application \"iTerm2\""))
        #expect(Place.tabScript(for: .iTerm).contains("sessions of t"))
        #expect(Place.tabScript(for: .terminal).contains("tell application \"Terminal\""))
    }

    @Test func editorsOpenTheirFolder() {
        for info in [["app": "com.todesktop.230313mzl4w4u92", "terminal": "vscode"], ["app": "dev.zed.Zed", "terminal": "zed"],
                     ["app": "com.jetbrains.intellij", "emulator": "JetBrains-JediTerm"]] {
            #expect(place(info).steps == [.openFolder("/Users/me/shop", app: info["app"]!)])
        }
    }

    @Test func wezTermAndKittyGoToThePane() {
        #expect(place(["app": "com.github.wez.wezterm", "terminal": "WezTerm", "wezPane": "7"]).steps
                == [.run(tool: "wezterm", arguments: ["cli", "activate-pane", "--pane-id", "7"]), .activate("com.github.wez.wezterm")])
        #expect(place(["app": "net.kovidgoyal.kitty", "terminal": "kitty", "kittyWindow": "3", "kittySocket": "unix:/tmp/kitty"]).steps
                == [.run(tool: "kitten", arguments: ["@", "--to", "unix:/tmp/kitty", "focus-window", "--match", "id:3"]), .activate("net.kovidgoyal.kitty")])
        // kitty without its remote control switched on: just the app.
        #expect(place(["app": "net.kovidgoyal.kitty", "terminal": "kitty", "kittyWindow": "3"]).steps == [.activate("net.kovidgoyal.kitty")])
    }

    /// Inside tmux the tab can't be found by its tty (tmux has its own), so: tmux's pane, then the app.
    @Test func tmuxPicksItsPaneThenTheApp() {
        let steps = place(["app": "com.apple.Terminal", "terminal": "tmux", "tty": "/dev/ttys020", "tmuxPane": "%3", "tmuxSocket": "/tmp/tmux-501/default"]).steps
        #expect(steps == [.run(tool: "tmux", arguments: ["-S", "/tmp/tmux-501/default", "select-window", "-t", "%3"]),
                          .run(tool: "tmux", arguments: ["-S", "/tmp/tmux-501/default", "select-pane", "-t", "%3"]),
                          .activate("com.apple.Terminal")])
    }

    @Test func anythingElseComesForward() {
        #expect(place(["app": "com.mitchellh.ghostty", "terminal": "ghostty", "tty": "/dev/ttys001"]).steps == [.activate("com.mitchellh.ghostty")])
        #expect(place([:]).steps.isEmpty)
    }

    @Test func theHelperNotesWhereItRuns() throws {
        let event = Data(#"{"hook_event_name":"Stop","cwd":"/x"}"#.utf8)
        let tagged = Place.addingHere(to: event, environment: ["TERM_PROGRAM": "WezTerm", "WEZTERM_PANE": "7", "TMUX": "/tmp/tmux-501/default,812,0",
                                                               "TMUX_PANE": "%3", "KITTY_WINDOW_ID": "2", "TERMINAL_EMULATOR": "JetBrains-JediTerm"])
        let json = try #require(try JSONSerialization.jsonObject(with: tagged) as? [String: Any])
        let place = Place(event: json)
        #expect(place.wezPane == "7")
        #expect(place.tmuxSocket == "/tmp/tmux-501/default")
        #expect(place.tmuxPane == "%3")
        #expect(place.kittyWindow == "2")
        #expect(place.kittySocket == nil)
        #expect(place.emulator == "JetBrains-JediTerm")
    }

    @Test func findsAToolOnlyWhereOneIs() {
        #expect(Place.find("wezterm", isExecutable: { $0 == "/opt/homebrew/bin/wezterm" }) == "/opt/homebrew/bin/wezterm")
        #expect(Place.find("wezterm", isExecutable: { _ in false }) == nil)
    }
}

/// Sessions in the same folder, folded under its name.
@MainActor
struct GroupingTests {
    let model: NotchModel = {
        let m = NotchModel()
        m.live = false
        m.hideIdle = false
        return m
    }()

    func send(_ name: String, session: String, folder: String) {
        let e: [String: Any] = ["hook_event_name": name, "session_id": session, "cwd": "/Users/me/\(folder)",
                                "tool_name": "Bash", "tool_input": ["command": "npm test"]]
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func shape(_ items: [NotchModel.Item]) -> [String] {
        items.map { item in
            switch item {
            case .project(_, let name, let sessions, let folded): "[\(name) \(sessions.count)\(folded ? " folded" : "")]"
            case .session(let session, let first): session.id + (first ? "*" : "")
            }
        }
    }

    @Test func alwaysGroupsSessionsThatShareAFolder() {
        model.groupingOverride = .always
        send("UserPromptSubmit", session: "a", folder: "shop")
        send("UserPromptSubmit", session: "b", folder: "blog")
        send("UserPromptSubmit", session: "c", folder: "shop")
        // Newest first; a project with one session stays a plain row.
        #expect(shape(model.items) == ["[shop 2]", "c*", "a", "b"])
        model.toggle(project: "/Users/me/shop")
        #expect(shape(model.items) == ["[shop 2 folded]", "b"])
        model.toggle(project: "/Users/me/shop")
        #expect(shape(model.items).count == 4)
    }

    @Test func aSessionThatNeedsYouStaysOnTopOutsideItsGroup() {
        model.groupingOverride = .always
        for id in ["a", "b", "c"] { send("UserPromptSubmit", session: id, folder: "shop") }
        send("PermissionRequest", session: "a", folder: "shop")
        #expect(shape(model.items) == ["a", "[shop 2]", "c*", "b"])
    }

    @Test func whenThereAreManyMeansFiveOrMore() {
        model.groupingOverride = .many
        for id in ["a", "b", "c", "d"] { send("UserPromptSubmit", session: id, folder: "shop") }
        #expect(shape(model.items) == ["d", "c", "b", "a"])
        send("UserPromptSubmit", session: "e", folder: "blog")
        #expect(shape(model.items) == ["e", "[shop 4]", "d*", "c", "b", "a"])
        model.groupingOverride = .never
        #expect(shape(model.items) == ["e", "d", "c", "b", "a"])
    }

    @Test func noSharedFolderNoHeadings() {
        model.groupingOverride = .always
        for (id, folder) in [("a", "one"), ("b", "two"), ("c", "three")] { send("UserPromptSubmit", session: id, folder: folder) }
        #expect(shape(model.items) == ["c", "b", "a"])
    }

    @Test func theNotchGrowsByTheHeadings() {
        model.groupingOverride = .never
        send("UserPromptSubmit", session: "a", folder: "shop")
        send("UserPromptSubmit", session: "b", folder: "shop")
        let plain = model.openSize.height
        model.groupingOverride = .always
        #expect(model.openSize.height == plain + NotchModel.projectHeight)
        model.toggle(project: "/Users/me/shop")
        #expect(model.openSize.height == plain + NotchModel.projectHeight - 2 * NotchModel.rowHeight)
    }
}
