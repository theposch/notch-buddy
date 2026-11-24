import Foundation
import Testing
@testable import NotchBuddy

/// Install and Remove on a sample settings file, never the real one.
struct HookFileTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "hooktest-\(UUID().uuidString)")
    var settings: URL { dir.appending(path: "settings.json") }
    var hookFile: HookFile { HookFile(settingsURL: settings, folder: dir.appending(path: "app")) }
    let ours = HookSettings.command(for: "/Apps/Notch Buddy.app/Contents/MacOS/NotchBuddy")
    let theirs = "'/Other/App/helper' --source claude"

    /// A file with another app's hooks and some unrelated settings, saved without a final newline.
    func writeSample() throws -> Data {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sample: [String: Any] = [
            "theme": "dark",
            "env": ["A": "1"],
            "hooks": ["Stop": [["hooks": [["type": "command", "command": theirs]]]],
                      "PreToolUse": [["matcher": "*", "hooks": [["type": "command", "command": theirs]]]]],
        ]
        let data = try JSONSerialization.data(withJSONObject: sample, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settings)
        return data
    }

    func read() throws -> [String: Any] { try HookFile.parse(Data(contentsOf: settings)) }

    func commands(_ event: String, in s: [String: Any]) -> [String] {
        let groups = (s["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    @Test func installAddsOursOnceAndKeepsTheRest() throws {
        _ = try writeSample()
        try hookFile.install(command: ours)
        try hookFile.install(command: ours)   // a second install must not add duplicates
        let s = try read()
        for event in HookSettings.events { #expect(commands(event, in: s).filter { $0 == ours }.count == 1) }
        #expect(commands("Stop", in: s).contains(theirs))
        #expect(commands("PreToolUse", in: s).contains(theirs))
        #expect(s["theme"] as? String == "dark")
    }

    @Test func removeRightAfterInstallRestoresTheFileExactly() throws {
        let original = try writeSample()
        try hookFile.install(command: ours)
        try hookFile.remove()
        #expect(try Data(contentsOf: settings) == original)
    }

    @Test func removeAfterOtherChangesTakesOutOnlyOurs() throws {
        _ = try writeSample()
        try hookFile.install(command: ours)
        // Something else edits the file in the meantime.
        var s = try read()
        s["model"] = "opus"
        try JSONSerialization.data(withJSONObject: s, options: [.prettyPrinted]).write(to: settings)

        try hookFile.remove()
        let after = try read()
        for event in HookSettings.events { #expect(!commands(event, in: after).contains(ours)) }
        #expect(commands("Stop", in: after) == [theirs])
        #expect(commands("PreToolUse", in: after) == [theirs])
        #expect(after["model"] as? String == "opus")
        #expect((after["hooks"] as? [String: Any])?.keys.sorted() == ["PreToolUse", "Stop"])
    }

    @Test func installWithNoFileAndRemoveLeavesNoFile() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try hookFile.install(command: ours)
        #expect(commands("Stop", in: try read()) == [ours])
        try hookFile.remove()
        #expect(!FileManager.default.fileExists(atPath: settings.path))
    }

    @Test func brokenFileIsLeftAlone() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let broken = Data("{ // not JSON".utf8)
        try broken.write(to: settings)
        #expect(throws: HookFile.Unreadable.self) { try hookFile.install(command: ours) }
        #expect(try Data(contentsOf: settings) == broken)
    }

    @Test func refreshMovesOursToTheNewPlaceOnly() throws {
        _ = try writeSample()
        let old = HookSettings.command(for: "/Apps/Old Name.app/Contents/MacOS/NotchBuddy")
        try hookFile.install(command: old)
        try hookFile.refresh(command: ours)
        let s = try read()
        for event in HookSettings.events { #expect(commands(event, in: s).filter { $0 == ours }.count == 1) }
        #expect(!commands("Stop", in: s).contains(old))
        #expect(commands("Stop", in: s).contains(theirs))
        // Up to date: nothing is written.
        let before = try Data(contentsOf: settings)
        try hookFile.refresh(command: ours)
        #expect(try Data(contentsOf: settings) == before)
    }

    @Test func refreshDoesNothingWhenNotConnected() throws {
        let original = try writeSample()
        try hookFile.refresh(command: ours)
        #expect(try Data(contentsOf: settings) == original)
    }

    @Test func permissionRequestGetsTheLongTimeLimit() throws {
        _ = try writeSample()
        try hookFile.install(command: ours)
        let groups = (try read()["hooks"] as? [String: Any])?["PermissionRequest"] as? [[String: Any]] ?? []
        let hook = groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }.first
        #expect(hook?["timeout"] as? Int == Permission.hookTimeout)
    }
}
