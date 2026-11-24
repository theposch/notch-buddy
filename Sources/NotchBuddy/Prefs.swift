import AppKit

/// The user's choices, kept in UserDefaults and changed in the settings window.
enum Prefs {
    static let clay = "#D97757"
    /// A few colours that sit well together on black.
    static let palette = [clay, "#E8C66A", "#8FBF6A", "#6AB7D9", "#B48AE0", "#E0809E", "#5FC2B0"]
    static let random = "random"

    static func register(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            "clawdColor": clay,          // one colour for every session, or "random"
            "soundNeedsYou": true,
            "soundFinished": false,
            "hideFinished": false,       // false: finished rows stay until clicked
            "rightSide": RightSide.auto.rawValue,
        ])
    }

    /// "#RRGGBB" or "random". Anything else falls back to clay.
    static var clawdColor: String {
        let value = UserDefaults.standard.string(forKey: "clawdColor") ?? clay
        return value == random || value.wholeMatch(of: /#[0-9A-Fa-f]{6}/) != nil ? value : clay
    }
    static var soundNeedsYou: Bool { UserDefaults.standard.bool(forKey: "soundNeedsYou") }
    static var soundFinished: Bool { UserDefaults.standard.bool(forKey: "soundFinished") }
    static var hideFinished: Bool { UserDefaults.standard.bool(forKey: "hideFinished") }
    static var rightSide: RightSide {
        RightSide(rawValue: UserDefaults.standard.string(forKey: "rightSide") ?? "") ?? .auto
    }

    /// What the closed notch shows on the right.
    enum RightSide: String, CaseIterable {
        case auto, word, sessions, usage

        var title: String {
            switch self {
            case .auto: "Auto"
            case .word: "Status word"
            case .sessions: "Sessions"
            case .usage: "Usage left"
            }
        }
    }

    /// A colour for a new session: one not in use yet when possible.
    static func pickColor(avoiding used: [String]) -> String {
        palette.filter { !used.contains($0) }.randomElement() ?? palette.randomElement()!
    }

    static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
