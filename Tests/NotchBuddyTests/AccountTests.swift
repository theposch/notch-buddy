import CommonCrypto
import Foundation
import Testing
@testable import NotchBuddy

/// Several Claude accounts: usage kept per account, sessions tagged with theirs,
/// and which one the closed notch follows.
@MainActor
@Suite(.serialized)
struct AccountTests {
    let model: NotchModel = {
        UserDefaults.standard.removeObject(forKey: "accounts")
        let m = NotchModel()
        m.live = false
        return m
    }()

    func usage(_ org: String, used: Double, from: String = "Terminal login") {
        model.takeUsage([Account.key: org, "from": from, "used_percentage": used,
                         "resets_at": Date().timeIntervalSince1970 + 3600])
    }

    func send(_ name: String, session: String, org: String? = nil) {
        var e: [String: Any] = ["hook_event_name": name, "session_id": session, "cwd": "/x/\(session)"]
        if let org { e[Account.key] = org }
        model.handle(try! JSONSerialization.data(withJSONObject: e))
    }

    func cleanUp() {
        for key in ["accounts", "usageFollows", "account.work.hidden", "account.home.name"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test func oneAccountLooksLikeBefore() {
        defer { cleanUp() }
        usage("home", used: 30)
        #expect(model.accounts.count == 1)
        #expect(!model.severalAccounts)
        #expect(model.usageLeft == 70)
    }

    @Test func usageIsKeptPerAccount() {
        defer { cleanUp() }
        usage("home", used: 30)
        usage("work", used: 85, from: "Desktop app")
        #expect(model.severalAccounts)
        #expect(model.accounts.first { $0.id == "work" }?.left == 15)
        #expect(model.accounts.first { $0.id == "work" }?.name == "Desktop")
        UserDefaults.standard.set("Studio", forKey: "account.home.name")
        #expect(model.accounts.first { $0.id == "home" }?.name == "Studio")
    }

    @Test func theClosedNotchFollowsTheSessionYouAreIn() {
        defer { cleanUp() }
        model.terminalOrg = "home"
        usage("home", used: 30)
        usage("work", used: 85)
        send("UserPromptSubmit", session: "a", org: "work")   // a desktop app session on the work account
        #expect(model.usageLeft == 15)
        send("UserPromptSubmit", session: "b")                // a Terminal session: the Terminal login's account
        #expect(model.account(of: model.lead!)?.id == "home")
        #expect(model.usageLeft == 70)
    }

    @Test func orTheLowestOrAlwaysOne() {
        defer { cleanUp() }
        usage("home", used: 30)
        usage("work", used: 85)
        Follow.saved = .lowest
        #expect(model.usageLeft == 15)
        Follow.saved = .account("home")
        #expect(model.usageLeft == 70)
    }

    @Test func switchedOffAccountsAreLeftOut() {
        defer { cleanUp() }
        usage("home", used: 30)
        usage("work", used: 85)
        UserDefaults.standard.set(true, forKey: "account.work.hidden")
        #expect(!model.severalAccounts)
        #expect(model.usageLeft == 70)
    }

    @Test func runningLowSaysWhichAccount() {
        defer { cleanUp() }
        usage("home", used: 30)
        usage("work", used: 50)
        usage("work", used: 95)
        #expect(model.shown?.word == "Terminal 5% left")
    }

    @Test func aNewAccountAlreadyLowIsNamed() {
        defer { cleanUp() }
        usage("home", used: 30)
        usage("work", used: 95, from: "Desktop app")
        #expect(model.shown?.word == "Desktop 5% left")
    }

    @Test func switchedOffAccountsStayQuiet() {
        defer { cleanUp() }
        usage("home", used: 30)
        UserDefaults.standard.set(true, forKey: "account.work.hidden")
        usage("work", used: 50)
        usage("work", used: 95)
        #expect(model.shown == nil)
    }

    @Test func usageFromBeforeWeKnewTheAccountIsReplaced() {
        defer { cleanUp() }
        model.takeUsage(["used_percentage": 10.0, "resets_at": Date().timeIntervalSince1970 + 3600])
        #expect(model.accounts.map(\.id) == [""])
        usage("home", used: 20)
        #expect(model.accounts.map(\.id) == ["home"])
    }

    @Test func theHelperAddsTheDesktopAppsAccount() throws {
        let event = Data(#"{"hook_event_name":"Stop"}"#.utf8)
        let tagged = Account.addingOrg(to: event, environment: ["CLAUDE_CODE_ORGANIZATION_UUID": "work"])
        let json = try #require(try JSONSerialization.jsonObject(with: tagged) as? [String: Any])
        #expect(json[Account.key] as? String == "work")
        #expect(Account.addingOrg(to: event, environment: [:]) == event)   // Terminal: left alone
    }

    @Test func readsTheTerminalAccount() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "claude-\(UUID()).json")
        try Data(#"{"oauthAccount": {"organizationUuid": "home"}}"#.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(Account.terminalOrg(file: file) == "home")
    }

    @Test func unlocksTheDesktopAppsCookie() {
        let key = DesktopLogin.derivedKey(Data("secret".utf8))
        let check = Data(repeating: 7, count: 32)
        for checked in [false, true] {
            let sealed = Data("v10".utf8) + encrypt((checked ? check : Data()) + Data("session-123".utf8), key: key)
            #expect(DesktopLogin.decrypt(sealed, key: key, checked: checked) == "session-123")
        }
    }

    /// The other half of what the desktop app does, to test unlocking against.
    func encrypt(_ plain: Data, key: Data) -> Data {
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var out = Data(count: plain.count + kCCBlockSizeAES128)
        var length = 0
        _ = out.withUnsafeMutableBytes { out in
            plain.withUnsafeBytes { plain in
                key.withUnsafeBytes { key in
                    iv.withUnsafeBytes { iv in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                key.baseAddress, key.count, iv.baseAddress, plain.baseAddress, plain.count,
                                out.baseAddress, out.count, &length)
                    }
                }
            }
        }
        return out.prefix(length)
    }
}

/// The open notch's top strip on a MacBook (camera in the middle) and on other screens.
@MainActor
@Suite(.serialized)
struct TopStripTests {
    let model: NotchModel = {
        UserDefaults.standard.removeObject(forKey: "accounts")
        let m = NotchModel()
        m.live = false
        return m
    }()

    func twoAccounts() {
        for (org, used) in [("home", 0.0), ("work", 29.0)] {
            model.takeUsage([Account.key: org, "from": org == "home" ? "Terminal login" : "Desktop app",
                             "used_percentage": used, "resets_at": Date().timeIntervalSince1970 + 3600])
        }
    }

    @Test func onAMacBookTheUsageStaysClearOfTheCamera() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        var macBook = NotchGeometry()
        macBook.hasNotch = true
        macBook.cameraWidth = 200
        model.geometry = macBook
        twoAccounts()
        let strip = model.usageStripWidth(short: model.shortUsageStrip)
        #expect((model.openWidth - macBook.cameraWidth) / 2 >= strip + 26)   // fits left of the camera
    }

    @Test func otherScreensAreNarrowerAndKeepTheNames() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        model.geometry = NotchGeometry()
        twoAccounts()
        #expect(!model.shortUsageStrip)
        #expect(model.openWidth == NotchGeometry.openWidthWithoutCamera)
    }
}
