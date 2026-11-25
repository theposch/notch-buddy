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
            "soundNeedsYou": true,       // the old on/off switches, still read until a sound is picked
            "soundFinished": false,
            "soundUsageLow": true,
            "peek": true,                // open by itself for a moment when Claude needs you
            "shortcuts": true,           // ⌥⌘Y / ⌥⌘N answer from any app
            "hideFinished": false,       // false: finished rows stay until clicked
            "rightSide": RightSide.auto.rawValue,
            "screen": ScreenChoice.builtIn.rawValue,
        ])
    }

    /// "#RRGGBB" or "random". Anything else falls back to clay.
    static var clawdColor: String {
        let value = UserDefaults.standard.string(forKey: "clawdColor") ?? clay
        return value == random || value.wholeMatch(of: /#[0-9A-Fa-f]{6}/) != nil ? value : clay
    }
    static var peek: Bool { UserDefaults.standard.bool(forKey: "peek") }
    /// Which moments the closed notch tells you about (Settings > Messages). Starts with the important ones.
    static var messages: Set<Notice.Kind> {
        get {
            guard let saved = UserDefaults.standard.stringArray(forKey: "messages") else { return Notice.Kind.important }
            return Set(saved.compactMap(Notice.Kind.init(rawValue:)))
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: "messages") }
    }

    static func shows(_ kind: Notice.Kind) -> Bool { messages.contains(kind) }

    /// The limit you set for a moment ("Usage is running low under 10%"), or its standard one.
    static func limit(_ kind: Notice.Kind) -> Int {
        let saved = UserDefaults.standard.integer(forKey: "limit.\(kind.rawValue)")
        return saved > 0 ? saved : kind.limit?.standard ?? 0
    }

    static func setLimit(_ kind: Notice.Kind, _ value: Int) {
        UserDefaults.standard.set(value, forKey: "limit.\(kind.rawValue)")
    }

    /// Clawd plays a little animation when something happens. On unless switched off.
    static var celebrations: Bool { UserDefaults.standard.object(forKey: "celebrations") as? Bool ?? true }
    static var shortcuts: Bool { UserDefaults.standard.bool(forKey: "shortcuts") }
    static var hideFinished: Bool { UserDefaults.standard.bool(forKey: "hideFinished") }
    static var rightSide: RightSide {
        RightSide(rawValue: UserDefaults.standard.string(forKey: "rightSide") ?? "") ?? .auto
    }

    static var screen: ScreenChoice {
        ScreenChoice(rawValue: UserDefaults.standard.string(forKey: "screen") ?? "") ?? .builtIn
    }

    /// Which screen the notch sits on.
    enum ScreenChoice: String, CaseIterable {
        case builtIn, external

        var title: String {
            switch self {
            case .builtIn: "MacBook screen"
            case .external: "External display, when connected"
            }
        }
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

    // MARK: Sounds

    static let silent = "None"
    /// The Mac's own alert sounds, the same ones System Settings offers.
    static let sounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        let names = files.map { ($0 as NSString).deletingPathExtension }.sorted()
        return names.isEmpty ? ["Glass", "Ping", "Purr"] : names
    }()

    /// The moments that can make a sound, each with its own pick.
    enum Moment: String, CaseIterable {
        case needsYou, finished, usageLow

        var title: String {
            switch self {
            case .needsYou: "When Claude needs you"
            case .finished: "When a session finishes"
            case .usageLow: "When usage runs low"
            }
        }
        var standard: String {
            switch self {
            case .needsYou: "Ping"
            case .finished: "Glass"
            case .usageLow: "Purr"
            }
        }
        var key: String { "sound.\(rawValue)" }
        /// Before sounds could be picked, each moment had an on/off switch.
        var oldSwitch: String { "sound" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    }

    /// The sound picked for a moment, or "None".
    static func sound(for moment: Moment, _ defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: moment.key) ?? (defaults.bool(forKey: moment.oldSwitch) ? moment.standard : silent)
    }

    /// Plays the sound picked for a moment, unless it's "None" or a Focus is on.
    static func play(_ moment: Moment) {
        guard !Focus.isOn else { return }
        preview(sound(for: moment))
    }

    /// Plays a sound right away, cutting off the one before (for trying sounds in Settings).
    static func preview(_ name: String) {
        guard name != silent, let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.stop()
        sound.play()
    }
}
