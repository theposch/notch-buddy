import Foundation

/// What a session has done so far, picked out of Claude's events: the lines it changed,
/// its last test run, a local server it started, its to-do list and helpers at work.
struct Work: Equatable {
    struct Tests: Hashable {
        var passed: Int?
        var failed: Int?
        var ok: Bool

        /// "42 passed", "2 failed", "Tests failed"
        var text: String {
            if !ok { return failed.map { "\($0) failed" } ?? "Tests failed" }
            return passed.map { "\($0) passed" } ?? "Tests passed"
        }
    }

    struct Todos: Equatable {
        var done: Int
        var total: Int
        /// The step it's on: "Wiring up the settings".
        var current: String?
    }

    var added = 0
    var removed = 0
    var files: Set<String> = []
    var tests: Tests?
    var server: URL?
    var todos: Todos?
    var helpers = 0
    /// Most helpers at once since they last all finished.
    var helperPeak = 0
    var lastCommand: String?
    /// How many test runs so far, so two runs with the same result still count as two.
    var testRuns = 0
    /// Git steps Claude took, counted so each new one is noticed.
    var commits = 0
    var pushes = 0
    var prsOpened = 0
    /// The number of the pull request Claude opened last.
    var openedPR: Int?
    /// Lines changed before your latest message, to tell how big this turn's change is.
    var changedAtPrompt = 0

    /// Lines added and removed since your latest message.
    var changedThisTurn: Int { added + removed - changedAtPrompt }

    /// "+212 −38 · 7 files"
    var linesText: String? {
        files.isEmpty ? nil : "+\(added) \u{2212}\(removed) · \(files.count) file\(files.count == 1 ? "" : "s")"
    }

    /// Takes in one of Claude's events.
    mutating func note(_ name: String, tool: String, event: [String: Any]) {
        let input = event["tool_input"] as? [String: Any] ?? [:]
        switch (name, tool) {
        case ("UserPromptSubmit", _):
            changedAtPrompt = added + removed
        case ("SubagentStart", _):
            helpers += 1
            helperPeak = max(helperPeak, helpers)
        case ("SubagentStop", _):
            helpers = max(0, helpers - 1)
            if helpers == 0 { helperPeak = 0 }
        case ("PreToolUse", "TodoWrite"):
            todos = Self.todos(input)
        case ("PostToolUse", "Edit"), ("PostToolUse", "MultiEdit"), ("PostToolUse", "Write"), ("PostToolUse", "NotebookEdit"):
            let lines = Self.lines(input: input, response: event["tool_response"])
            added += lines.added
            removed += lines.removed
            if let path = input["file_path"] as? String ?? input["notebook_path"] as? String { files.insert(path) }
        case ("PostToolUse", "Bash"), ("PostToolUseFailure", "Bash"):
            let command = input["command"] as? String ?? ""
            lastCommand = command
            let output = Self.output(event)
            if Self.runsTests(command) {
                tests = Self.tests(in: output, failed: name == "PostToolUseFailure")
                testRuns += 1
            }
            if let url = Self.localServer(in: output) { server = url }
            if name == "PostToolUse" { noteGit(command, output: output) }
        default:
            break
        }
    }

    /// A commit, a push or a new pull request, from a command that worked.
    private mutating func noteGit(_ command: String, output: String) {
        if command.contains(/\bgit\s+(?:-C\s+\S+\s+)?commit\b/) { commits += 1 }
        if command.contains(/\bgit\s+(?:-C\s+\S+\s+)?push\b/) { pushes += 1 }
        if command.contains(/\bgh\s+pr\s+create\b/) {
            prsOpened += 1
            openedPR = output.matches(of: /\/pull\/(\d+)/).last.flatMap { Int($0.1) }
        }
    }

    // MARK: Reading events

    /// Lines added and removed by an edit. Claude sends the exact change with its answer;
    /// without that, compare what was replaced with what replaced it.
    static func lines(input: [String: Any], response: Any?) -> (added: Int, removed: Int) {
        let response = response as? [String: Any] ?? [:]
        if response["type"] as? String == "create", let content = response["content"] as? String {
            return (lineCount(content), 0)
        }
        if let hunks = response["structuredPatch"] as? [[String: Any]], !hunks.isEmpty {
            let lines = hunks.flatMap { $0["lines"] as? [String] ?? [] }
            return (lines.filter { $0.hasPrefix("+") }.count, lines.filter { $0.hasPrefix("-") }.count)
        }
        let edits = input["edits"] as? [[String: Any]] ?? [input]
        return edits.reduce((0, 0)) { sum, edit in
            let old = edit["old_string"] as? String ?? ""
            let new = edit["new_string"] as? String ?? edit["content"] as? String ?? ""
            let change = diff(old: old, new: new)
            return (sum.0 + change.added, sum.1 + change.removed)
        }
    }

    /// Lines that differ, after skipping the ones at the start and end that are the same.
    static func diff(old: String, new: String) -> (added: Int, removed: Int) {
        var a = old.isEmpty ? [] : old.components(separatedBy: "\n")
        var b = new.isEmpty ? [] : new.components(separatedBy: "\n")
        while let first = a.first, first == b.first { a.removeFirst(); b.removeFirst() }
        while let last = a.last, last == b.last { a.removeLast(); b.removeLast() }
        return (b.count, a.count)
    }

    static func lineCount(_ text: String) -> Int {
        text.isEmpty ? 0 : text.components(separatedBy: "\n").count - (text.hasSuffix("\n") ? 1 : 0)
    }

    /// Everything a command printed, or the error Claude got back when it failed.
    static func output(_ event: [String: Any]) -> String {
        let response = event["tool_response"] as? [String: Any] ?? [:]
        return [response["stdout"], response["stderr"], event["tool_response"], event["error"]]
            .compactMap { $0 as? String }.joined(separator: "\n")
    }

    /// True for a command that runs a project's tests: "swift test", "npm test", "pytest", …
    static func runsTests(_ command: String) -> Bool {
        command.contains(/\b(?:swift|npm|yarn|pnpm|bun|go|cargo|mix|dotnet|make|deno)\s+(?:run\s+)?test\b|\b(?:pytest|jest|vitest|rspec|unittest|phpunit)\b|\bxcodebuild\b.*\btest\b/)
    }

    /// How a test run went, from what it printed. Test tools word it differently, so try a few.
    static func tests(in output: String, failed: Bool) -> Tests {
        func first(_ patterns: [Regex<(Substring, Substring)>]) -> Int? {
            patterns.lazy.compactMap { output.firstMatch(of: $0).flatMap { Int($0.1) } }.first
        }
        let failures = first([/(\d+) (?:tests? )?(?:failed|failing)/, /with (\d+) (?:failures?|issues?)/])
        let passes = first([/(\d+) (?:tests? )?(?:passed|passing)/, /with (\d+) tests? in \d+ suites? passed/, /Executed (\d+) tests?/])
        return Tests(passed: passes, failed: failures, ok: !failed && (failures ?? 0) == 0)
    }

    /// The last local address a command printed: "http://localhost:4174".
    static func localServer(in output: String) -> URL? {
        let found = output.matches(of: /https?:\/\/(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]):\d{2,5}[^\s'"<>)\]]*/).last
        return found.flatMap { URL(string: String($0.output).replacingOccurrences(of: "0.0.0.0", with: "localhost")) }
    }

    /// Claude's to-do list: how many are done, and the one it's working on.
    static func todos(_ input: [String: Any]) -> Todos? {
        guard let list = input["todos"] as? [[String: Any]], !list.isEmpty else { return nil }
        let current = list.first { $0["status"] as? String == "in_progress" }
        return Todos(done: list.filter { $0["status"] as? String == "completed" }.count, total: list.count,
                     current: current.flatMap { $0["activeForm"] as? String ?? $0["content"] as? String })
    }
}
