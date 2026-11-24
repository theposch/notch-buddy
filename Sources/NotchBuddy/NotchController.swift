import AppKit
import SwiftUI

/// What the notch view shows. The controller changes it; the view follows.
@MainActor @Observable
final class NotchModel {
    var geometry = NotchGeometry()
    var isOpen = false
}

/// A see-through window over the top centre of the screen: notch-sized when closed,
/// panel-sized when open. The black notch shape is drawn inside it.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Closed, every click goes to whatever is underneath.
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Puts the notch on the right screen and opens it while the mouse is over it.
@MainActor
final class NotchController {
    private let model = NotchModel()
    private let panel = NotchPanel()
    private var screenFrame = NSRect.zero
    private var watchers: [Any] = []

    init() {
        let host = NSHostingView(rootView: NotchView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        place()

        // Screens plugged in, unplugged or rearranged.
        watchers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        })

        // Follow the mouse. "Global" sees it while other apps are under it,
        // "local" while it is over our own open panel.
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) { watchers.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) { watchers.append(local) }
    }

    private func place() {
        guard let screen = NotchGeometry.bestScreen() else { panel.orderOut(nil); return }
        screenFrame = screen.frame
        model.geometry = NotchGeometry(screen: screen)
        panel.orderFrontRegardless()
        setOpen(false, animated: false)
    }

    private func mouseMoved() {
        let size = model.isOpen ? NotchGeometry.openSize : model.geometry.closedSize
        // Grow the area by a point so the very top row of pixels counts too.
        let inside = topCentre(size).insetBy(dx: 0, dy: -1).contains(NSEvent.mouseLocation)
        if inside != model.isOpen { setOpen(inside, animated: true) }
    }

    private func setOpen(_ open: Bool, animated: Bool) {
        panel.ignoresMouseEvents = !open
        // Open: make room for the panel first. Closed: shrink back to just the notch
        // once the animation ends, so nothing beside it can catch a click.
        if open { panel.setFrame(topCentre(NotchGeometry.openSize), display: true) }
        withAnimation(animated ? .spring(duration: 0.32, bounce: 0.18) : nil) {
            model.isOpen = open
        }
        guard !open else { return }
        Task { @MainActor [weak self] in
            if animated { try? await Task.sleep(for: .milliseconds(450)) }
            guard let self, !self.model.isOpen else { return }
            self.panel.setFrame(self.topCentre(self.model.geometry.closedSize), display: true)
        }
    }

    /// A rectangle of the given size, hanging from the top centre of the screen.
    private func topCentre(_ size: CGSize) -> NSRect {
        NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
               width: size.width, height: size.height)
    }
}
