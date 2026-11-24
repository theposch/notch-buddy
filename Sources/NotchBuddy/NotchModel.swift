import AppKit
import Observation

struct Session: Identifiable {
    enum State { case ready, working, waiting, done }
    let id: String
    var folder: String
    var state: State
    let started = Date()
}

/// Everything the notch shows. Claude Code events change it; the view follows.
@MainActor @Observable
final class NotchModel {
    var geometry = NotchGeometry()
    var isOpen = false
    /// Newest first.
    private(set) var sessions: [Session] = []
    /// The status word Clawd's page last told us ("Pondering…", "Needs you", …).
    var clawdWord = ""
    private var celebrating = false
    @ObservationIgnored private var celebration: Task<Void, Never>?

    // MARK: What Clawd and the wings show

    var clawdMode: String {
        if sessions.contains(where: { $0.state == .waiting }) { return "waiting" }
        if sessions.contains(where: { $0.state == .working }) { return "working" }
        return celebrating ? "done" : "life"
    }

    /// Right wing: Clawd's word while working, otherwise how many sessions are busy.
    var rightText: String? {
        if clawdMode == "working", !clawdWord.isEmpty { return clawdWord }
        let busy = sessions.filter { $0.state == .working || $0.state == .waiting }.count
        return busy > 0 ? "\(busy)" : nil
    }

    static let wingFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    /// Both wings get the same width, so the notch stays centred on the camera.
    var wingWidth: CGFloat {
        guard let text = rightText else { return NotchGeometry.wing }
        let width = (text as NSString).size(withAttributes: [.font: Self.wingFont]).width
        return max(NotchGeometry.wing, ceil(width) + 20)
    }

    var closedSize: CGSize {
        CGSize(width: geometry.cameraWidth + wingWidth * 2, height: geometry.barHeight)
    }

    static let rowHeight: CGFloat = 40
    static let maxRows = 8

    var openSize: CGSize {
        let rows = min(sessions.count, Self.maxRows)
        let body = rows == 0 ? 108 : CGFloat(rows) * Self.rowHeight + 16
        return CGSize(width: NotchGeometry.openSize.width, height: geometry.barHeight + body)
    }

    // MARK: Claude Code events

    func handle(_ data: Data) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = event["session_id"] as? String,
              let name = event["hook_event_name"] as? String else { return }
        let folder = (event["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Claude"

        if name == "SessionEnd" {
            sessions.removeAll { $0.id == id }
            return
        }
        let current = sessions.first { $0.id == id }?.state
        let next: Session.State
        switch name {
        case "SessionStart":
            next = current ?? .ready
        case "UserPromptSubmit", "PreToolUse", "PostToolUse":
            next = .working
        case "Notification":
            // "Waiting for your input" after a finished turn: done already says that.
            let idle = (event["notification_type"] as? String) == "idle_prompt"
                || ((event["message"] as? String) ?? "").contains("waiting for your input")
            next = idle && (current == .done || current == .ready) ? current! : .waiting
        case "Stop":
            next = .done
            if current != .done { celebrate() }
        default:
            return
        }
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            sessions[i].state = next
            sessions[i].folder = folder
        } else {
            sessions.insert(Session(id: id, folder: folder, state: next), at: 0)
        }
    }

    /// A finished row stays until it's clicked.
    func dismiss(_ session: Session) {
        guard session.state == .done else { return }
        sessions.removeAll { $0.id == session.id }
    }

    /// Clawd's short "done" dance before he goes back to his day off.
    private func celebrate() {
        celebration?.cancel()
        celebrating = true
        celebration = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.celebrating = false
        }
    }
}
