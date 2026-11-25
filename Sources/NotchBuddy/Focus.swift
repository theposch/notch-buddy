import Intents

/// macOS Focus (Do Not Disturb, Work, Sleep, …). While one is on, Notch Buddy stays quiet.
/// macOS has to allow Notch Buddy to know whether a Focus is on.
enum Focus {
    /// Asks by itself only the very first time Notch Buddy opens. After that, only from Settings.
    /// (macOS may forget the answer when the app is rebuilt; this way it doesn't nag each time.)
    static func askOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "askedFocus") else { return }
        defaults.set(true, forKey: "askedFocus")
        ask { _ in }
    }

    static var needsAsking: Bool { INFocusStatusCenter.default.authorizationStatus == .notDetermined }

    static func ask(then done: @escaping @Sendable (Bool) -> Void) {
        guard needsAsking else { done(true); return }
        INFocusStatusCenter.default.requestAuthorization { done($0 == .authorized) }
    }

    static var isOn: Bool {
        INFocusStatusCenter.default.authorizationStatus == .authorized
            && INFocusStatusCenter.default.focusStatus.isFocused == true
    }
}
