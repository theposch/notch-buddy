import AppKit

/// The sizes of the notch on one screen, in points.
struct NotchGeometry: Equatable {
    /// Each side of the closed notch sticks out this far past the camera.
    static let wing: CGFloat = 56
    /// The open panel.
    static let openSize = CGSize(width: 470, height: 140)
    /// Other screens have no camera to leave room for, so the open panel can be narrower.
    static let openWidthWithoutCamera: CGFloat = 440
    static let closedRadius: CGFloat = 12
    static let openRadius: CGFloat = 24
    /// The curved shoulders where the notch meets the menu bar.
    static let closedShoulder: CGFloat = 6
    static let openShoulder: CGFloat = 14

    /// True on a MacBook screen with a real camera notch.
    var hasNotch = false
    /// Width of the camera area in the middle: the real notch on a MacBook. Other screens have
    /// no camera, so just a small gap between Clawd and the words.
    var cameraWidth: CGFloat = 16
    /// Height of the closed notch.
    var barHeight: CGFloat = 32

    var closedSize: CGSize {
        CGSize(width: cameraWidth + Self.wing * 2, height: barHeight)
    }

    init() {}

    init(screen: NSScreen) {
        // macOS tells us the usable menu-bar space left and right of the camera;
        // whatever is left over in the middle is the notch.
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            hasNotch = true
            cameraWidth = screen.frame.width - left.width - right.width
            barHeight = screen.safeAreaInsets.top
        }
    }

    /// The screen to sit on, following the "Show on" setting.
    @MainActor
    static func bestScreen() -> NSScreen? {
        let screens = NSScreen.screens
        return pick(screens.map { $0.safeAreaInsets.top > 0 }, external: Prefs.screen == .external)
            .map { screens[$0] }
    }

    /// Which screen, given whether each one has a notch (the first is the one with the menu bar).
    /// The MacBook screen, or an external one when that's chosen and one is plugged in.
    /// Without the chosen kind, the other kind; with no notch anywhere, the first screen.
    static func pick(_ hasNotch: [Bool], external: Bool) -> Int? {
        hasNotch.firstIndex(of: !external) ?? hasNotch.indices.first
    }
}
