import SwiftUI

/// A moment worth reacting to: tests passing or failing, a pull request merging or passing its checks,
/// a big change finishing, or a team of helpers all done. Clawd plays its animation once,
/// the row and the closed notch say what happened, and the bigger ones peek the notch open.
struct Cheer: Equatable {
    enum Kind: Equatable {
        case passed, fixed, failed, merged, checksPassed, bigChange, helpersDone
    }

    var kind: Kind
    /// What happened, in a few words: "91 passed", "PR #87 merged".
    var text: String
    /// Tells two cheers of the same kind apart, so each one plays.
    var id = UUID()

    /// How long the row and the notch show it.
    static let seconds: Double = 4.5
    /// A change this big (lines added plus removed in one turn) gets its own cheer.
    static let bigChange = 500

    /// The animation on Clawd's page.
    var animation: String {
        switch kind {
        case .passed: "hop"
        case .fixed: "fixed"
        case .failed: "facepalm"
        case .merged: "merged"
        case .checksPassed: "trophy"
        case .bigChange: "bigone"
        case .helpersDone: "highfive"
        }
    }

    /// Said in the closed notch and on the row.
    var word: String {
        switch kind {
        case .passed: "Tests pass"
        case .fixed: "Fixed it!"
        case .failed: "Tests failed"
        case .merged: "Merged!"
        case .checksPassed: "Checks passed"
        case .bigChange: "Big one!"
        case .helpersDone: "Helpers done"
        }
    }

    @MainActor var color: Color {
        switch kind {
        case .passed, .fixed, .checksPassed: NotchView.green
        case .failed: NotchView.red
        case .merged: NotchView.purple
        case .bigChange, .helpersDone: NotchView.clay
        }
    }

    // MARK: Spotting them

    /// What a session's latest event is worth celebrating, comparing it with how it was before.
    static func after(_ before: Session?, _ now: Session) -> Cheer? {
        guard let before else { return nil }
        let was = before.work, work = now.work
        if work.testRuns > was.testRuns, let tests = work.tests {
            let brokeBefore = was.tests.map { !$0.ok } ?? false
            if !tests.ok { return Cheer(kind: .failed, text: tests.text, quiet: brokeBefore) }
            return brokeBefore ? Cheer(kind: .fixed, text: "Tests pass again · " + tests.text) : Cheer(kind: .passed, text: tests.text)
        }
        if now.state == .done, before.state != .done, work.changedThisTurn >= bigChange, let lines = work.linesText {
            return Cheer(kind: .bigChange, text: lines)
        }
        if was.helpers > 0, work.helpers == 0, was.helperPeak >= 2 {
            return Cheer(kind: .helpersDone, text: "All \(was.helperPeak) helpers finished")
        }
        return nil
    }

    /// What changed about a branch's pull request is worth celebrating.
    static func after(_ before: PullRequest?, _ now: PullRequest?) -> Cheer? {
        guard let before, let now, before.number == now.number else { return nil }
        if now.merged, !before.merged { return Cheer(kind: .merged, text: "PR #\(now.number) merged") }
        if now.checks == .passed, before.checks == .running {
            return Cheer(kind: .checksPassed, text: "PR #\(now.number) · checks passed")
        }
        return nil
    }

    /// Failing again after failing before: still worth a facepalm, but not worth opening the notch.
    private var quiet = false

    /// Only news opens the notch: tests that just broke or just got fixed, a merge, passing checks,
    /// a big change. Tests passing again and again, or helpers finishing, stay in the closed notch.
    var opensNotch: Bool {
        switch kind {
        case .passed, .helpersDone: false
        case .failed, .fixed, .merged, .checksPassed, .bigChange: !quiet
        }
    }

    init(kind: Kind, text: String, quiet: Bool = false) {
        self.kind = kind
        self.text = text
        self.quiet = quiet
    }
}
