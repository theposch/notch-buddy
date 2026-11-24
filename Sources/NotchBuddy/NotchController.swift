import AppKit
import SwiftUI

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

/// Lets the first click on a row count, even though our panel never becomes the active window.
final class NotchHostingView: NSHostingView<NotchView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Puts the notch on the right screen, opens it while the mouse is over it,
/// and feeds it Claude Code events.
@MainActor
final class NotchController {
    private let model = NotchModel()
    private let panel = NotchPanel()
    private var screenFrame = NSRect.zero
    private var watchers: [Any] = []
    private var listener: EventListener?
    private var shrink: Task<Void, Never>?

    init() {
        let host = NotchHostingView(rootView: NotchView(model: model, menu: menu))
        host.sizingOptions = []
        panel.contentView = host
        place()
        followSize()

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

        // Events from Claude Code, passed on by the hook helper.
        let model = model
        listener = EventListener(onEvent: { data, reply in
            Task { @MainActor in
                withAnimation(.spring(duration: 0.32, bounce: 0.18)) { model.handle(data, reply: reply) }
            }
        }, onGone: { reply in
            Task { @MainActor in
                withAnimation { model.replyGone(reply) }
            }
        })
    }

    private func place() {
        guard let screen = NotchGeometry.bestScreen() else { panel.orderOut(nil); return }
        screenFrame = screen.frame
        model.geometry = NotchGeometry(screen: screen)
        panel.orderFrontRegardless()
        setOpen(false, animated: false)
    }

    private func mouseMoved() {
        let size = model.isOpen ? model.openSize : model.closedSize
        // Grow the area by a point so the very top row of pixels counts too.
        let inside = topCentre(size).insetBy(dx: 0, dy: -1).contains(NSEvent.mouseLocation)
        if inside != model.isOpen { setOpen(inside, animated: true) }
    }

    private func setOpen(_ open: Bool, animated: Bool) {
        panel.ignoresMouseEvents = !open
        withAnimation(animated ? .spring(duration: 0.32, bounce: 0.18) : nil) {
            model.isOpen = open
        }
        fit(animated: animated)
    }

    /// Whenever the notch's size changes (new rows, a longer word), resize the window to match.
    private func followSize() {
        withObservationTracking {
            _ = model.closedSize
            _ = model.openSize
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.fit(animated: true)
                self?.mouseMoved()   // the panel may have shrunk out from under the mouse
                self?.followSize()
            }
        }
    }

    /// Grow the window at once; shrink it only after the animation has played,
    /// so nothing beside the notch can catch a click.
    private func fit(animated: Bool) {
        let target = model.isOpen ? model.openSize : model.closedSize
        let now = panel.frame.size
        panel.setFrame(topCentre(CGSize(width: max(now.width, target.width),
                                        height: max(now.height, target.height))), display: true)
        shrink?.cancel()
        shrink = Task { [weak self] in
            if animated { try? await Task.sleep(for: .milliseconds(450)) }
            guard let self, !Task.isCancelled else { return }
            self.panel.setFrame(self.topCentre(target), display: true)
        }
    }

    /// A rectangle of the given size, hanging from the top centre of the screen.
    private func topCentre(_ size: CGSize) -> NSRect {
        NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
               width: size.width, height: size.height)
    }

    // MARK: Right-click menu

    private var menu: NotchMenu {
        NotchMenu(
            installHooks: { Self.changeHooks(install: true) },
            removeHooks: { Self.changeHooks(install: false) }
        )
    }

    private static func changeHooks(install: Bool) {
        let alert = NSAlert()
        do {
            let file = HookFile()
            if install {
                try file.install(command: HookSettings.command(for: Bundle.main.executablePath ?? ""))
                alert.messageText = "Claude hooks installed"
                alert.informativeText = "New Claude Code sessions will show up in the notch. A backup of your settings was saved."
            } else {
                try file.remove()
                alert.messageText = "Claude hooks removed"
                alert.informativeText = "Notch Buddy's entries were taken out of Claude's settings. Everything else is as it was."
            }
        } catch {
            alert.messageText = "Couldn't change Claude's settings"
            alert.informativeText = error.localizedDescription
        }
        NSApp.activate()
        alert.runModal()
    }
}

/// The actions behind the notch's right-click menu.
struct NotchMenu {
    var installHooks: () -> Void
    var removeHooks: () -> Void
}
