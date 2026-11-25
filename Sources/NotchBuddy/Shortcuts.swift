import Carbon
import Foundation

/// ⌥⌘Y allows and ⌥⌘N denies the request at the top of the notch, from any app.
/// Uses the system's hot keys, which need no special permission.
@MainActor
final class Shortcuts {
    enum Key: UInt32 { case allow = 1, deny = 2 }

    nonisolated static let allowText = "\u{2325}\u{2318}Y"
    nonisolated static let denyText = "\u{2325}\u{2318}N"

    private let pressed: (Key) -> Void
    private var keys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    init(pressed: @escaping (Key) -> Void) {
        self.pressed = pressed
    }

    var isOn: Bool { !keys.isEmpty }

    func turn(on: Bool) {
        on ? start() : stop()
    }

    private func start() {
        guard keys.isEmpty else { return }
        var kind = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, me in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard let me, let key = Key(rawValue: id.id) else { return noErr }
            let shortcuts = Unmanaged<Shortcuts>.fromOpaque(me).takeUnretainedValue()
            MainActor.assumeIsolated { shortcuts.pressed(key) }
            return noErr
        }, 1, &kind, Unmanaged.passUnretained(self).toOpaque(), &handler)
        for (key, code) in [(Key.allow, kVK_ANSI_Y), (.deny, kVK_ANSI_N)] {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4E425544), id: key.rawValue)   // "NBUD"
            if RegisterEventHotKey(UInt32(code), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref {
                keys.append(ref)
            }
        }
    }

    private func stop() {
        keys.forEach { UnregisterEventHotKey($0) }
        keys = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
