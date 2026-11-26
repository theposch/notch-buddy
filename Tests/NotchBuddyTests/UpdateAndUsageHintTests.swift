import Foundation
import Testing
@testable import NotchBuddy

/// One-click updates: what counts as a download we trust, and what gets checked before the swap.
struct UpdateInstallTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "nb-update-\(UUID().uuidString.prefix(8))")

    @discardableResult
    func run(_ tool: String, _ arguments: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try! process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// A tiny pretend app, signed for this Mac like a release without a developer certificate.
    func app(in name: String, version: String, id: String = "local.notchbuddy.test", signed: Bool = true) throws -> URL {
        let app = folder.appending(path: "\(name)/Notch Buddy.app")
        try FileManager.default.createDirectory(at: app.appending(path: "Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: app.appending(path: "Contents/Resources"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: app.appending(path: "Contents/MacOS/Fake"))
        try Data("hello".utf8).write(to: app.appending(path: "Contents/Resources/page.html"))
        let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleShortVersionString": version,
                                   "CFBundleExecutable": "Fake", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appending(path: "Contents/Info.plist"))
        if signed { #expect(run("/usr/bin/codesign", "--force", "--sign", "-", app.path) == 0) }
        return app
    }

    /// Zips an app the way a release is zipped, and describes it the way the downloads page would.
    func release(of app: URL, version: String) throws -> (zip: URL, release: Updater.Release) {
        let zip = folder.appending(path: "release-\(UUID().uuidString.prefix(6)).zip")
        #expect(run("/usr/bin/ditto", "-c", "-k", "--keepParent", app.path, zip.path) == 0)
        let page = URL(string: "https://github.com/me/notch-buddy/releases/tag/v\(version)")!
        return (zip, Updater.Release(version: version, page: page,
                                     download: URL(string: "https://github.com/me/notch-buddy/releases/download/v\(version)/a.zip"),
                                     digest: Updater.sha256(try Data(contentsOf: zip))))
    }

    func scratch() throws -> URL {
        let scratch = folder.appending(path: "scratch-\(UUID().uuidString.prefix(6))")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return scratch
    }

    @Test func readsTheDownloadFromTheReleasePage() {
        let page = Data(#"""
        {"tag_name":"v0.5","html_url":"https://github.com/me/notch-buddy/releases/tag/v0.5",
         "assets":[{"name":"notes.txt","browser_download_url":"https://github.com/me/notch-buddy/releases/download/v0.5/notes.txt"},
                   {"name":"Notch-Buddy-0.5.zip","digest":"sha256:ABCDEF",
                    "browser_download_url":"https://github.com/me/notch-buddy/releases/download/v0.5/Notch-Buddy-0.5.zip"}]}
        """#.utf8)
        let release = Updater.newer(in: page, than: "0.4")
        #expect(release?.download?.lastPathComponent == "Notch-Buddy-0.5.zip")
        #expect(release?.digest == "abcdef")
    }

    @Test func aDownloadFromSomewhereElseIsNotTrusted() {
        let page = URL(string: "https://github.com/me/notch-buddy/releases/tag/v0.5")!
        func trusted(_ address: String) -> Bool { Updater.trusted(URL(string: address)!, page: page) }
        #expect(trusted("https://github.com/me/notch-buddy/releases/download/v0.5/a.zip"))
        #expect(!trusted("https://example.com/me/notch-buddy/releases/download/v0.5/a.zip"))   // another site
        #expect(!trusted("https://github.com/someone/notch-buddy/releases/download/v0.5/a.zip"))   // another person's project
        #expect(!trusted("http://github.com/me/notch-buddy/releases/download/v0.5/a.zip"))   // not encrypted
        // A release with only such a download still says there's an update; Update then opens the page.
        let other = Data(#"{"tag_name":"v0.5","html_url":"https://github.com/me/notch-buddy/releases/tag/v0.5","assets":[{"name":"a.zip","browser_download_url":"https://example.com/a.zip","digest":"sha256:aa"}]}"#.utf8)
        #expect(Updater.newer(in: other, than: "0.4")?.download == nil)
        #expect(Updater.newer(in: other, than: "0.4")?.digest == nil)
    }

    @Test func installsTheNewVersionWhereTheOldOneWas() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = try app(in: "Applications", version: "1.0")
        let (zip, release) = try release(of: try app(in: "built", version: "2.0"), version: "2.0")
        let new = try Updater.unpack(zip, in: try scratch(), release: release, replacing: old)
        try Updater.swap(new, into: old)
        #expect(Updater.info(old)?["CFBundleShortVersionString"] as? String == "2.0")
        #expect(FileManager.default.isExecutableFile(atPath: old.appending(path: "Contents/MacOS/Fake").path))
    }

    @Test func aDownloadThatDoesntMatchThePageIsRefused() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = try app(in: "Applications", version: "1.0")
        var (zip, release) = try release(of: try app(in: "built", version: "2.0"), version: "2.0")
        release.digest = String(repeating: "0", count: 64)
        #expect(throws: Updater.Problem.changed) { try Updater.unpack(zip, in: try scratch(), release: release, replacing: old) }
        #expect(Updater.info(old)?["CFBundleShortVersionString"] as? String == "1.0")
    }

    @Test func anotherAppOrAnotherVersionIsRefused() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = try app(in: "Applications", version: "1.0")
        let (other, otherRelease) = try release(of: try app(in: "other", version: "2.0", id: "com.someone.else"), version: "2.0")
        #expect(throws: Updater.Problem.notOurs) { try Updater.unpack(other, in: try scratch(), release: otherRelease, replacing: old) }
        let (zip, release) = try release(of: try app(in: "built", version: "1.5"), version: "2.0")   // says 2.0, is 1.5
        #expect(throws: Updater.Problem.notOurs) { try Updater.unpack(zip, in: try scratch(), release: release, replacing: old) }
    }

    @Test func anUnsignedOrChangedAppIsRefused() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = try app(in: "Applications", version: "1.0")
        let (unsigned, unsignedRelease) = try release(of: try app(in: "unsigned", version: "2.0", signed: false), version: "2.0")
        #expect(throws: Updater.Problem.signature) { try Updater.unpack(unsigned, in: try scratch(), release: unsignedRelease, replacing: old) }
        // Signed, then something inside was changed.
        let changed = try app(in: "changed", version: "2.0")
        try Data("something else".utf8).write(to: changed.appending(path: "Contents/Resources/page.html"))
        let (zip, release) = try release(of: changed, version: "2.0")
        #expect(throws: Updater.Problem.signature) { try Updater.unpack(zip, in: try scratch(), release: release, replacing: old) }
    }

    @Test func someSpotsCantBeUpdatedInPlace() {
        #expect(!Updater.canReplace(URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/123/d/Notch Buddy.app")))
        #expect(!Updater.canReplace(URL(fileURLWithPath: "/System/Applications/Notch Buddy.app")))
        #expect(Updater.canReplace(FileManager.default.temporaryDirectory.appending(path: "Notch Buddy.app")))
    }
}

/// "Usage needs your OK" in the open notch's top strip.
@MainActor
@Suite(.serialized)
struct UsageHintTests {
    let model: NotchModel = {
        UserDefaults.standard.removeObject(forKey: "accounts")
        let m = NotchModel()
        m.live = false
        return m
    }()

    @Test func saysSoOnlyWhenALoginIsWaiting() {
        #expect(NotchModel.usageHint(needing: [], hasFigures: false, short: false) == nil)
        #expect(NotchModel.usageHint(needing: [.terminal], hasFigures: false, short: false)
                == NotchModel.UsageHint(text: "Usage needs your OK", button: "Allow"))
        // No room beside a MacBook's camera: just the button.
        #expect(NotchModel.usageHint(needing: [.terminal], hasFigures: false, short: true) == NotchModel.UsageHint(button: "Allow usage"))
    }

    @Test func besideAnotherAccountsUsageItNamesTheLogin() {
        #expect(NotchModel.usageHint(needing: [.terminal], hasFigures: true, short: false)?.button == "Allow Terminal")
        #expect(NotchModel.usageHint(needing: [.desktop], hasFigures: true, short: true)?.button == "Allow Desktop")
        #expect(NotchModel.usageHint(needing: [.terminal, .desktop], hasFigures: true, short: false)?.button == "Allow usage")
    }

    @Test func theNotchFollowsTheLogins() {
        #expect(model.usageHint(short: false) == nil)
        model.loginChecks = [LoginUsage(.terminal, state: .needsOK), LoginUsage(.desktop, state: .off)]
        #expect(model.usageHint(short: false)?.text == "Usage needs your OK")
        #expect(model.loginsNeedingOK.map(\.source) == [.terminal])
        model.loginChecks = [LoginUsage(.terminal, state: .checked(Date()))]
        #expect(model.usageHint(short: false) == nil)
    }

    @Test func itStaysClearOfTheCameraOnAMacBook() {
        defer { UserDefaults.standard.removeObject(forKey: "accounts") }
        var macBook = NotchGeometry()
        macBook.hasNotch = true
        macBook.cameraWidth = 200
        model.geometry = macBook
        model.loginChecks = [LoginUsage(.terminal, state: .needsOK)]
        let strip = model.usageStripWidth(short: model.shortUsageStrip)
        #expect(strip > 0)
        #expect((model.openWidth - macBook.cameraWidth) / 2 >= strip + 26)
        // With another account's usage showing too.
        model.takeUsage([Account.key: "work", "from": "Desktop app", "used_percentage": 20.0,
                         "resets_at": Date().timeIntervalSince1970 + 3600])
        let both = model.usageStripWidth(short: model.shortUsageStrip)
        #expect(both > 0)
        #expect((model.openWidth - macBook.cameraWidth) / 2 >= both + 26)
    }
}
