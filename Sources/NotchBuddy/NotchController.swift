import AppKit
import SwiftUI

/// A see-through window over the top centre of the screen, always the same size.
/// The black notch shape grows and shrinks inside it; resizing the window itself
/// while animating would make the shape jump.
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
    private var updates: Task<Void, Never>?
    private let settings = SettingsWindow()
    /// The welcome stays open until the mouse has been over it and left again.
    private var pinned = false
    private var mouseVisited = false
    /// Opening or closing that waits a moment, in case the mouse is only passing by.
    private var pending: Task<Void, Never>?
    /// Open by itself for a moment because Claude needs you.
    private var peeking: Task<Void, Never>?
    /// ⌥⌘Y / ⌥⌘N: Allow or Deny the top request from any app.
    private var shortcuts: Shortcuts?
    /// The window's fixed size: room for the biggest the notch can get.
    private static let room = CGSize(width: 800, height: 640)

    init() {
        let host = NotchHostingView(rootView: NotchView(model: model, actions: actions))
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

        // A setting changed: turn the shortcuts on or off, and move over if "Show on" now means another screen.
        watchers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // A moment later, in case macOS says this while a view is being drawn.
            Task { @MainActor in
                guard let self else { return }
                if self.shortcuts?.isOn != Prefs.shortcuts { self.shortcuts?.turn(on: Prefs.shortcuts) }
                guard NotchGeometry.bestScreen()?.frame != self.screenFrame else { return }
                self.place()
            }
        })

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

        model.onPeek = { [weak self] in self?.peek() }
        model.terminalOrg = Account.terminalOrg()
        let checks = LoginUsage.Source.allCases.map(LoginUsage.init)
        for check in checks {
            check.onUsage = { [weak model, source = check.source] usage in
                if source == .terminal { model?.terminalOrg = Account.terminalOrg() }
                model?.takeUsage(usage)
            }
        }
        model.loginChecks = checks
        model.onDone = { Task { for check in checks { await check.check() } } }
        shortcuts = Shortcuts { [weak self] key in
            guard let self, let session = self.model.shortcutTarget else { return }
            withAnimation { self.model.answer(session, key == .allow ? .allow : .deny) }
        }
        shortcuts?.turn(on: Prefs.shortcuts)
        updates = Updater.watch { model.update = $0 }
        firstLaunch()
    }

    /// The very first time: open at login, and say hello unless Claude Code is already connected.
    private func firstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "launchedBefore") else { return }
        defaults.set(true, forKey: "launchedBefore")
        LoginItem.set(true)
        guard !Connection().isConnected else { return }
        model.welcome = true
        pinned = true
        setOpen(true, animated: true)
    }

    private func place() {
        guard let screen = NotchGeometry.bestScreen() else { panel.orderOut(nil); return }
        screenFrame = screen.frame
        model.geometry = NotchGeometry(screen: screen)
        panel.setFrame(topCentre(CGSize(width: min(Self.room.width, screenFrame.width),
                                        height: min(Self.room.height, screenFrame.height))), display: true)
        panel.orderFrontRegardless()
        setOpen(false, animated: false)
    }

    /// Whether the mouse is over the black shape.
    private var mouseInside: Bool {
        let size = model.isOpen ? model.openSize : model.closedSize
        // Grow the area by a point so the very top row of pixels counts too.
        return topCentre(size).insetBy(dx: 0, dy: -1).contains(NSEvent.mouseLocation)
    }

    private func mouseMoved() {
        let inside = mouseInside
        // Only the black shape takes clicks; everywhere else they go to what's underneath.
        panel.ignoresMouseEvents = !inside
        if pinned {
            if inside { mouseVisited = true }
            if !mouseVisited || inside { return }
            pinned = false
        }
        // Peeking: the mouse coming over makes it a normal open; otherwise it closes by itself.
        if peeking != nil {
            guard inside else { return }
            peeking?.cancel()
            peeking = nil
        }
        guard inside != model.isOpen else { pending?.cancel(); pending = nil; return }
        // Wait a moment first, so the mouse passing by on its way to the menu bar doesn't open it.
        guard pending == nil else { return }
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(inside ? 120 : 80))
            guard let self, !Task.isCancelled else { return }
            self.pending = nil
            if self.mouseInside == inside, inside != self.model.isOpen { self.setOpen(inside, animated: true) }
        }
    }

    private func setOpen(_ open: Bool, animated: Bool) {
        panel.ignoresMouseEvents = !open
        // Springs, like the Dynamic Island: a soft settle when opening, none when closing.
        // A spring can turn around midway, so changing your mind looks smooth too.
        withAnimation(animated ? (open ? .spring(duration: 0.34, bounce: 0.16) : .spring(duration: 0.26, bounce: 0)) : nil) {
            model.isOpen = open
            // Rows vanish without hearing the mouse leave, so forget which one it was over.
            if !open { model.hovered = nil }
        }
    }

    /// Claude needs you, or something worth celebrating happened: open for a few seconds, like a call arriving on a phone, then close
    /// again unless the mouse came over.
    private func peek() {
        guard Prefs.peek, !model.isOpen, !model.welcome else { return }
        setOpen(true, animated: true)
        panel.ignoresMouseEvents = !mouseInside   // clicks beside it still go to what's underneath
        peeking?.cancel()
        peeking = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.peeking = nil
            if !self.mouseInside { self.setOpen(false, animated: true) }
        }
    }

    /// Whenever the notch's size changes (new rows, a longer word), check the mouse again.
    private func followSize() {
        withObservationTracking {
            _ = model.closedSize
            _ = model.openSize
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.mouseMoved()   // the panel may have shrunk out from under the mouse
                self?.followSize()
            }
        }
    }

    /// A rectangle of the given size, hanging from the top centre of the screen.
    private func topCentre(_ size: CGSize) -> NSRect {
        NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
               width: size.width, height: size.height)
    }

    // MARK: Buttons and menu

    private var actions: NotchActions {
        NotchActions(
            settings: { [weak self] in
                guard let self else { return }
                self.settings.show(model: self.model)
            },
            quit: { NSApp.terminate(nil) },
            connect: { [weak self] in self?.connect() }
        )
    }

    /// The welcome's one button.
    private func connect() {
        if let problem = Connection().connect() {
            let alert = NSAlert()
            alert.messageText = "Couldn't connect to Claude Code"
            alert.informativeText = problem
            NSApp.activate()
            alert.runModal()
            return
        }
        withAnimation { model.welcome = false }
        pinned = false
        mouseMoved()
    }
}
