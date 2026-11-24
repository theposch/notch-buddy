import AppKit

/// The sizes of the notch on one screen, in points.
struct NotchGeometry: Equatable {
    /// Each side of the closed notch sticks out this far past the camera.
    static let wing: CGFloat = 56
    /// The open panel.
    static let openSize = CGSize(width: 470, height: 140)
    static let closedRadius: CGFloat = 12
    static let openRadius: CGFloat = 24

    /// True on a MacBook screen with a real camera notch.
    var hasNotch = false
    /// Width of the camera area in the middle (the physical notch, or our own on other screens).
    var cameraWidth: CGFloat = 120
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

    /// The screen with a notch, or the main screen when none has one.
    @MainActor
    static func bestScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }
}
