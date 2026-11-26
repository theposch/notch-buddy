import Foundation

/// The extra things a session row can show beyond its name and status line.
/// The raw values are kept in Settings, so don't rename them.
enum RowPiece: String, CaseIterable {
    case model, account, context, time, branch, lines, pullRequest, tests, server, todo, helpers, cost

    var title: String {
        switch self {
        case .model: "Model"
        case .account: "Account"
        case .context: "Conversation size"
        case .time: "Time"
        case .branch: "Branch"
        case .lines: "Lines changed"
        case .pullRequest: "Pull request"
        case .tests: "Tests"
        case .server: "Local preview"
        case .todo: "To-do list"
        case .helpers: "Helpers at work"
        case .cost: "Cost so far"
        }
    }

    /// What it looks like, for Settings.
    var example: String {
        switch self {
        case .model: "Opus 5.5"
        case .account: "Work"
        case .context: "57% full"
        case .time: "4m"
        case .branch: "tokens-2"
        case .lines: "+88 \u{2212}41 · 3 files"
        case .pullRequest: "PR #77 · checks running"
        case .tests: "42 passed"
        case .server: "localhost:6006"
        case .todo: "2 of 5 · Auditing colour use"
        case .helpers: "+2"
        case .cost: "$0.62"
        }
    }

    /// It has a small form that can sit on the row all the time: a tag, an icon, a ring.
    /// A branch name, a line count and an address are only words.
    var hasGlance: Bool { self != .branch && self != .lines && self != .server }

    /// Its small form says less than its words (an icon for "42 passed"), so the words
    /// still come in the details line.
    var saysMoreOnHover: Bool { [.tests, .pullRequest, .todo, .context].contains(self) }
}

/// Where a piece shows on a row.
enum RowPlace: String, CaseIterable {
    /// Always on the row, small.
    case glance
    /// In the details line, while the mouse is over the row.
    case hover
    case off

    var title: String {
        switch self {
        case .glance: "At a glance"
        case .hover: "On hover"
        case .off: "Off"
        }
    }
}

/// What you chose to see on session rows (Settings > Sessions).
enum RowPrefs {
    /// Ready-made choices. Changing a piece by hand makes it "Custom".
    enum Preset: String, CaseIterable {
        case minimal, balanced, everything

        var title: String { rawValue.capitalized }

        func place(_ piece: RowPiece) -> RowPlace {
            switch self {
            case .minimal:
                return piece == .context || piece == .time ? .glance : .off
            case .balanced:
                switch piece {
                case .context, .time, .pullRequest, .tests, .helpers: return .glance
                case .cost: return .off
                default: return .hover
                }
            case .everything:
                return piece.hasGlance ? .glance : .hover
            }
        }

        /// "Everything" also shows the details without hovering.
        var always: Bool { self == .everything }
    }

    /// Settings lists them by topic.
    static let groups: [(title: String, pieces: [RowPiece])] = [
        ("Session", [.model, .account, .context, .time]),
        ("Git", [.branch, .lines, .pullRequest]),
        ("Checks", [.tests, .server]),
        ("Progress", [.todo, .helpers]),
        ("Cost", [.cost]),
    ]

    static func key(_ piece: RowPiece) -> String { "row.\(piece.rawValue)" }
    static let alwaysKey = "row.always"

    /// Where a piece shows: your choice, or Balanced's.
    static func place(_ piece: RowPiece, _ defaults: UserDefaults = .standard) -> RowPlace {
        let saved = defaults.string(forKey: key(piece)).flatMap(RowPlace.init(rawValue:))
        let place = saved ?? Preset.balanced.place(piece)
        return place == .glance && !piece.hasGlance ? .hover : place
    }

    static func set(_ piece: RowPiece, _ place: RowPlace, _ defaults: UserDefaults = .standard) {
        defaults.set(place.rawValue, forKey: key(piece))
    }

    /// Show the details line without hovering.
    static func always(_ defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: alwaysKey) }
    static func setAlways(_ on: Bool, _ defaults: UserDefaults = .standard) { defaults.set(on, forKey: alwaysKey) }

    /// The preset your choices match right now, or nil for a mix of your own.
    static func preset(_ defaults: UserDefaults = .standard) -> Preset? {
        Preset.allCases.first { preset in
            preset.always == always(defaults) && RowPiece.allCases.allSatisfy { place($0, defaults) == preset.place($0) }
        }
    }

    static func apply(_ preset: Preset, _ defaults: UserDefaults = .standard) {
        for piece in RowPiece.allCases { set(piece, preset.place(piece), defaults) }
        setAlways(preset.always, defaults)
    }
}
