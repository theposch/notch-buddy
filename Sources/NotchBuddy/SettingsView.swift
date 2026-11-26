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
    @AppStorage("screen") private var screen = Prefs.ScreenChoice.builtIn.rawValue
    @AppStorage("peek") private var peek = true
    @AppStorage("celebrations") private var celebrations = true
    @AppStorage("messages") private var messages: String = ""   // only to notice changes; Prefs reads it
    @State private var choosingMessages = false
    @AppStorage("shortcuts") private var shortcuts = true
    @AppStorage("loginUsage") private var loginUsage = false
    @AppStorage("desktopUsage") private var desktopUsage = false
    @State private var choosingAccounts = false
    @State private var openAtLogin = LoginItem.isOn
    @State private var focusNeedsAsking = Focus.needsAsking

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
                Picker(selection: $rightSide) {
                    ForEach(Prefs.RightSide.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Text("Right side of the notch")
                    if rightSide == Prefs.RightSide.usage.rawValue, model.usageLeft == nil {
                        Text(loginUsage || desktopUsage ? "Waiting for the first check of your usage."
                             : "Choose where usage comes from under \u{201C}Usage and accounts\u{201D} below, or use Claude Code in the Terminal.")
                    }
                }
                Picker("Show on", selection: $screen) {
                    ForEach(Prefs.ScreenChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Finished sessions", selection: $hideFinished) {
                    Text("Stay until I click").tag(false)
                    Text("Hide right away").tag(true)
                }
            }

            Section("Sounds") {
                ForEach(Prefs.Moment.allCases, id: \.self) { SoundPicker(moment: $0) }
            }

            Section {
                Toggle(isOn: $peek) {
                    Text("Peek open")
                    Text("When Claude needs you, and for big news like a merge.")
                }
                LabeledContent {
                    Button("Choose\u{2026}") { choosingMessages = true }
                } label: {
                    Text("Messages on the closed notch")
                    Text(messagesSummary)
                }
                LabeledContent {
                    Button("Set up\u{2026}") { choosingAccounts = true }
                } label: {
                    Text("Usage and accounts")
                    Text(accountsSummary)
                }
                Toggle(isOn: $celebrations) {
                    Text("Clawd reacts")
                    Text("A little animation when tests pass or fail, Claude pushes, a pull request merges, and more.")
                }
                Toggle(isOn: $shortcuts) {
                    Text("Keyboard shortcuts")
                    Text("\(Shortcuts.allowText) allows and \(Shortcuts.denyText) denies the top request, from any app.")
                }
                LabeledContent {
                    if focusNeedsAsking {
                        Button("Allow…") {
                            Focus.ask { _ in Task { @MainActor in focusNeedsAsking = Focus.needsAsking } }
                        }
                    } else {
                        Button("Open Focus Settings…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!)
                        }
                    }
                } label: {
                    Text("Quiet during Focus")
                    Text("Works when \u{201C}Share Focus Status\u{201D} is on in Focus settings.")
                }
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
                    LabeledContent {
                        if model.updating == .working {
                            ProgressView().controlSize(.small)
                        } else if case .failed = model.updating {
                            Link("Open downloads page", destination: update.page)
                        } else {
                            Button(update.download == nil ? "Download" : "Update now") { model.installUpdate() }
                        }
                    } label: {
                        Text("Version \(update.version) is available")
                        if case .failed(let why) = model.updating {
                            Text(why).foregroundStyle(.red)
                        } else if update.download != nil {
                            Text(model.updating == .working ? "Downloading and installing\u{2026}"
                                 : "Downloads it, installs it and restarts Notch Buddy.")
                        }
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
        .onChange(of: "\(color)\(rightSide)\(hideFinished)") { model.playExample() }
        .sheet(isPresented: $choosingMessages) { MessagesView(model: model) }
        .sheet(isPresented: $choosingAccounts) { AccountsView(model: model) }
    }

    /// "From the Terminal login and the desktop app · 2 accounts"
    private var accountsSummary: String {
        let sources = [loginUsage ? "the Terminal login" : nil, desktopUsage ? "the desktop app" : nil].compactMap { $0 }
        let from = sources.isEmpty ? "Only from Claude Code while it runs in the Terminal"
                                   : "From " + sources.joined(separator: " and ")
        let count = model.shownAccounts.count
        return count > 1 ? "\(from) \u{00B7} \(count) accounts" : from
    }

    /// "Important (13 of 24)", "All", "None", or "Custom (9 of 24)".
    private var messagesSummary: String {
        _ = messages
        let chosen = Prefs.messages, all = Notice.Kind.listed.count
        switch chosen {
        case []: return "None"
        case Set(Notice.Kind.listed): return "All \(all)"
        case Notice.Kind.important: return "Important (\(chosen.count) of \(all))"
        default: return "Custom (\(chosen.count) of \(all))"
        }
    }
}

/// A menu of the Mac's alert sounds for one moment. Picking one plays it, so you hear it.
struct SoundPicker: View {
    let moment: Prefs.Moment
    @State private var name: String

    init(moment: Prefs.Moment) {
        self.moment = moment
        _name = State(initialValue: Prefs.sound(for: moment))
    }

    var body: some View {
        Picker(moment.title, selection: $name) {
            Text("None").tag(Prefs.silent)
            Divider()
            ForEach(Prefs.sounds, id: \.self) { Text($0).tag($0) }
        }
        .onChange(of: name) { _, picked in
            UserDefaults.standard.set(picked, forKey: moment.key)
            Prefs.preview(picked)
        }
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
