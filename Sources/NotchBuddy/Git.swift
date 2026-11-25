import Foundation

/// The branch a session works on, and its pull request on GitHub.
enum Git {
    /// Where the hook helper puts the branch in an event.
    static let branchKey = "notch_buddy_branch"

    /// The event with the branch of its folder added (the helper's side).
    static func addingBranch(to event: Data) -> Data {
        guard var e = try? JSONSerialization.jsonObject(with: event) as? [String: Any],
              let folder = e["cwd"] as? String, let branch = branch(at: folder) else { return event }
        e[branchKey] = branch
        return (try? JSONSerialization.data(withJSONObject: e)) ?? event
    }

    /// The branch checked out in a folder or the nearest folder above it: "main".
    /// A short commit id when no branch is checked out. Nil outside a repository.
    static func branch(at folder: String) -> String? {
        var dir = URL(fileURLWithPath: folder)
        for _ in 0..<30 {
            let git = dir.appending(path: ".git")
            if let head = headFile(git), let text = try? String(contentsOf: head, encoding: .utf8) {
                let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("ref: refs/heads/") { return String(line.dropFirst("ref: refs/heads/".count)) }
                return line.isEmpty ? nil : String(line.prefix(7))
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
        return nil
    }

    /// ".git" is usually a folder; in a worktree it's a file pointing at the real one.
    private static func headFile(_ git: URL) -> URL? {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: git.path, isDirectory: &isFolder) else { return nil }
        if isFolder.boolValue { return git.appending(path: "HEAD") }
        guard let text = try? String(contentsOf: git, encoding: .utf8), text.hasPrefix("gitdir: ") else { return nil }
        let path = text.dropFirst("gitdir: ".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let target = path.hasPrefix("/") ? URL(fileURLWithPath: path) : git.deletingLastPathComponent().appending(path: path)
        return target.appending(path: "HEAD")
    }
}

/// A branch's pull request and whether its checks pass, as GitHub's own command-line tool tells us.
struct PullRequest: Hashable {
    enum Checks { case running, passed, failed, none }
    var number: Int
    var url: URL
    var checks: Checks
    var merged = false

    /// "PR #87 · checks running"
    var text: String {
        if merged { return "PR #\(number) · merged" }
        switch checks {
        case .running: return "PR #\(number) · checks running"
        case .passed: return "PR #\(number) · checks passed"
        case .failed: return "PR #\(number) · checks failed"
        case .none: return "PR #\(number)"
        }
    }

    /// Asks `gh` about the branch checked out in a folder. Nil when gh isn't installed or
    /// signed in, there's no pull request, or it takes too long.
    static func look(in folder: String) async -> PullRequest? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let places = ["/opt/homebrew/bin", "/usr/local/bin", home + "/.local/bin", "/usr/bin"]
        guard let gh = places.map({ $0 + "/gh" }).first(where: FileManager.default.isExecutableFile) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gh)
        process.arguments = ["pr", "view", "--json", "number,url,state,statusCheckRollup"]
        process.currentDirectoryURL = URL(fileURLWithPath: folder)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = (places + ["/bin"]).joined(separator: ":")
        environment["GH_PROMPT_DISABLED"] = "1"
        process.environment = environment
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { done in
            process.terminationHandler = { finished in
                let data = out.fileHandleForReading.readDataToEndOfFile()
                done.resume(returning: finished.terminationStatus == 0 ? parse(data) : nil)
            }
            do { try process.run() } catch { done.resume(returning: nil); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { if process.isRunning { process.terminate() } }
        }
    }

    /// Reads gh's answer. Any failing check fails the lot; any unfinished one means still running.
    static func parse(_ data: Data) -> PullRequest? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = json["number"] as? Int, let url = (json["url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let rollup = json["statusCheckRollup"] as? [[String: Any]] ?? []
        let results = rollup.map { check -> Checks in
            let conclusion = (check["conclusion"] as? String ?? check["state"] as? String ?? "").uppercased()
            let status = (check["status"] as? String ?? "COMPLETED").uppercased()
            if ["FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"].contains(conclusion) { return .failed }
            if status != "COMPLETED" || ["PENDING", "EXPECTED", ""].contains(conclusion) { return .running }
            return .passed
        }
        let checks: Checks = results.isEmpty ? .none : results.contains(.failed) ? .failed : results.contains(.running) ? .running : .passed
        return PullRequest(number: number, url: url, checks: checks, merged: json["state"] as? String == "MERGED")
    }
}
