import AppKit
import ServiceManagement
import SwiftUI

/// The settings window: one page, no tabs. Every change plays the short example
/// in the real notch, so you see what it does.
struct SettingsView: View {
    let model: NotchModel
    let connection: Connection

    @AppStorage("clawdColor") private var color = Prefs.clay
    @AppStorage("rightSide") private var rightSide = Prefs.RightSide.auto.rawValue
    @AppStorage("hideFinished") private var hideFinished = false
    @AppStorage("soundNeedsYou") private var soundNeedsYou = true
    @AppStorage("soundFinished") private var soundFinished = false
    @State private var openAtLogin = LoginItem.isOn

    var body: some View {
        Form {
            Section {
                LabeledContent("Clawd colour") {
                    HStack(spacing: 8) {
                        ForEach(Prefs.palette, id: \.self) { hex in
                            Swatch(hex: hex, chosen: color == hex) { color = hex }
                        }
                    }
                }
                Toggle("Random for each session", isOn: Binding(
                    get: { color == Prefs.random },
                    set: { color = $0 ? Prefs.random : Prefs.clay }))
                Picker("Right side of the notch", selection: $rightSide) {
                    ForEach(Prefs.RightSide.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Finished sessions", selection: $hideFinished) {
                    Text("Stay until I click").tag(false)
                    Text("Hide right away").tag(true)
                }
            }

            Section {
                Toggle("Sound when Claude needs you", isOn: $soundNeedsYou)
                Toggle("Sound when a session finishes", isOn: $soundFinished)
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in openAtLogin = LoginItem.set(on) }
                if LoginItem.needsApproval {
                    Button("Allow it in System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonStyle(.link)
                }
            }

            Section {
                ConnectionRow(model: model, connection: connection)
                if let update = model.update {
                    LabeledContent("Version \(update.version) is available") {
                        Link("Download", destination: update.page)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Show example") { model.playExample() }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 460)
        .fixedSize()
        .onChange(of: "\(color)\(rightSide)\(hideFinished)\(soundNeedsYou)\(soundFinished)") { model.playExample() }
    }
}

/// One colour to pick.
struct Swatch: View {
    let hex: String
    let chosen: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(.primary, lineWidth: chosen ? 2 : 0).padding(-3))
        }
        .buttonStyle(.plain)
        .help(hex)
    }
}

/// "Claude Code connection" with Connect or Disconnect, and a line saying whether it's working.
struct ConnectionRow: View {
    let model: NotchModel
    let connection: Connection
    @State private var connected = false
    @State private var problem: String?

    var body: some View {
        LabeledContent {
            Button(connected ? "Disconnect" : "Connect") {
                problem = connected ? connection.disconnect() : connection.connect()
                connected = connection.isConnected
            }
        } label: {
            Text("Claude Code connection")
            Text(problem ?? status).foregroundStyle(problem == nil ? .secondary : Color.red)
        }
        .onAppear { connected = connection.isConnected }
    }

    private var status: String {
        guard connected else { return "Not connected" }
        guard let heard = model.lastHeard else { return "Connected. Waiting to hear from Claude Code." }
        return "Working. Last heard from Claude Code \(heard.formatted(.relative(presentation: .named)))."
    }
}

/// Connect and Disconnect, the same from the welcome and from settings.
struct Connection {
    var hook: String { HookSettings.command(for: Bundle.main.executablePath ?? "") }
    var isConnected: Bool { HookFile().isConnected }

    /// Nil when it worked, otherwise what went wrong.
    func connect() -> String? {
        do { try HookFile().install(command: hook); return nil } catch { return error.localizedDescription }
    }

    func disconnect() -> String? {
        do { try HookFile().remove(); return nil } catch { return error.localizedDescription }
    }
}

/// Opening at login, through macOS's own login items.
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Turns it on or off; returns whether it's on afterwards.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        return isOn || (on && needsApproval)
    }
}

extension Color {
    /// "#D97757"
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

/// The window around the settings page. There's only ever one.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?

    func show(model: NotchModel) {
        if window == nil {
            // The window takes its size from the page, so nothing scrolls.
            let page = NSHostingController(rootView: SettingsView(model: model, connection: Connection()))
            page.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: page)
            window.styleMask = [.titled, .closable]
            window.title = "Notch Buddy Settings"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
