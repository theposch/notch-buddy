import AppKit
import ServiceManagement
import SwiftUI

/// The sections of the settings window, in the order the sidebar lists them.
enum SettingsPane: String, CaseIterable {
    case general, look, rows, messages, sounds, usage, shortcuts, about

    var title: String {
        switch self {
        case .general: "General"
        case .look: "Look"
        case .rows: "Sessions"
        case .messages: "Messages"
        case .sounds: "Sounds"
        case .usage: "Usage and accounts"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    /// The symbol on its tile in the sidebar (Look has Clawd himself).
    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .look: "sparkles"
        case .rows: "list.bullet"
        case .messages: "bubble.left.fill"
        case .sounds: "speaker.wave.2.fill"
        case .usage: "chart.pie.fill"
        case .shortcuts: "command"
        case .about: "info"
        }
    }

    var color: Color {
        switch self {
        case .general: Color(red: 0.56, green: 0.56, blue: 0.58)
        case .look: NotchView.clay
        case .rows: Color(red: 0.04, green: 0.52, blue: 1)
        case .messages: Color(red: 1, green: 0.27, blue: 0.23)
        case .sounds: Color(red: 1, green: 0.22, blue: 0.37)
        case .usage: Color(red: 0.19, green: 0.69, blue: 0.29)
        case .shortcuts: Color(red: 0.37, green: 0.36, blue: 0.9)
        case .about: Color(red: 1, green: 0.62, blue: 0.04)
        }
    }
}

/// The settings window: sections down the left, and on the right each section opens with a live
/// piece of the notch, so you see what a choice does as you make it.
struct SettingsView: View {
    let model: NotchModel
    let connection: Connection
    @AppStorage("settingsPane") private var paneName = SettingsPane.look.rawValue

    private var pane: SettingsPane { SettingsPane(rawValue: paneName) ?? .look }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 216)
                .background(SidebarMaterial().ignoresSafeArea())
            Divider().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch pane {
                    case .general: GeneralPane(model: model, connection: connection)
                    case .look: LookPane(model: model)
                    case .rows: RowsPane(model: model)
                    case .messages: MessagesPane(model: model)
                    case .sounds: SoundsPane()
                    case .usage: UsagePane(model: model)
                    case .shortcuts: ShortcutsPane()
                    case .about: AboutPane(model: model)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        }
        // Fills the window, title bar included; the window sets the size (see SettingsWindow).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(NotchView.clay)
        .ignoresSafeArea()
    }

    /// Clawd and the app's name, then the sections. About sits alone at the bottom.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                ClawdView(mode: DayPart.now.clawdMode, color: model.restingColor)
                    .frame(width: 44, height: 29)
                    .frame(width: 46, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.black))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notch Buddy").font(.system(size: 13, weight: .semibold))
                    Text("Version \(Updater.currentVersion)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
            Divider().padding(.horizontal, 6).padding(.bottom, 8)

            ForEach(SettingsPane.allCases.filter { $0 != .about }, id: \.self) { item($0) }
            Spacer(minLength: 0)
            item(.about)
        }
        .padding(.horizontal, 10)
        .padding(.top, 44)   // below the window's close button
        .padding(.bottom, 14)
    }

    private func item(_ which: SettingsPane) -> some View {
        Button { paneName = which.rawValue } label: {
            HStack(spacing: 8) {
                SidebarTile(pane: which)
                Text(which.title).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            .foregroundStyle(pane == which ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(pane == which ? NotchView.clay : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A section's little coloured tile in the sidebar.
struct SidebarTile: View {
    let pane: SettingsPane

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [pane.color.opacity(0.82), pane.color], startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 22)
            .overlay {
                if pane == .look { ClawdGlyph().fill(.white).frame(width: 14, height: 10) }
                else { Image(systemName: pane.symbol).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white) }
            }
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
    }
}

/// Clawd as a tiny outline: body, arms and four legs.
struct ClawdGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12, v = rect.height / 8
        var path = Path()
        path.addRect(CGRect(x: 2 * u, y: 0, width: 8 * u, height: 6 * v))
        path.addRect(CGRect(x: 0, y: 2 * v, width: 12 * u, height: 2 * v))
        for x in [2.0, 4.2, 6.8, 9.0] { path.addRect(CGRect(x: x * u, y: 6 * v, width: u, height: 2 * v)) }
        return path
    }
}

/// The translucent grey a Mac sidebar has.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// MARK: Building blocks

/// A section's title and the one line that says what it's for.
struct PaneHeader: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 22, weight: .bold))
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A rounded box of rows, with an optional heading above and a note below.
struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 10) }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.035)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
            if let footer {
                Text(footer).font(.system(size: 11.5)).foregroundStyle(.secondary).padding(.horizontal, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One setting: its name, a line about it, and its control at the end.
struct SettingsRow<Control: View>: View {
    let label: String
    var text: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 13))
                if let text, !text.isEmpty {
                    Text(text).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 44)
        // A hairline above each row; the first one's hides under the box's own edge.
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.09)).frame(height: 1) }
    }
}

/// A strip of Mac screen with the notch hanging from its top edge: the live preview in each section.
struct NotchPreview<Content: View>: View {
    var height: CGFloat = 150
    var caption: String? = nil
    /// Open: rounder corners, like the real one.
    var open = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color(red: 0.36, green: 0.49, blue: 0.61))
            RadialGradient(colors: [Color(red: 0.25, green: 0.44, blue: 0.59), .clear], center: UnitPoint(x: 0, y: -0.25), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.96, green: 0.78, blue: 0.61), .clear], center: UnitPoint(x: 0.92, y: 1.35), startRadius: 0, endRadius: 420)
            content
                .background(alignment: .top) {
                    NotchShape(shoulder: 8, corner: open ? 22 : 11).fill(.black).padding(.horizontal, -8)
                }
                .environment(\.colorScheme, .dark)
            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 9)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
    }
}

/// The closed notch for a preview: Clawd in the left wing, room for the camera, something on the right.
struct ClosedNotch<Right: View>: View {
    let mode: String
    let color: String
    var onWord: ((String) -> Void)? = nil
    var wing: CGFloat = 118
    @ViewBuilder var right: Right

    var body: some View {
        HStack(spacing: 0) {
            ClawdView(mode: mode, color: color, onWord: onWord)
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: wing, alignment: .leading)
            Circle().fill(Color(white: 0.07)).frame(width: 6, height: 6).frame(width: 150)   // the camera
            right
                .font(Font(NotchModel.wingFont))
                .lineLimit(1)
                .frame(width: wing)
        }
        .frame(height: 32)
    }
}

/// A key, drawn as a keycap.
struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12.5, weight: .medium))
            .frame(minWidth: 14)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
            .shadow(color: Color.primary.opacity(0.14), radius: 0, y: 1)
    }
}

/// A sample session for the previews, so they show the real rows.
extension Session {
    @MainActor static func sample(_ state: State = .working) -> Session {
        var s = Session(id: "settings-preview", folder: "design-tokens", state: state, color: "#E8C66A")
        s.title = "Design tokens"
        s.model = "Opus 5.5"
        s.branch = "tokens-2"
        s.activity = state == .working ? "Editing tokens.css" : nil
        s.workingSince = Date().addingTimeInterval(-252)
        s.changed = Date().addingTimeInterval(-252)
        s.context = 57
        s.cost = 0.62
        s.work.added = 88
        s.work.removed = 41
        s.work.files = ["tokens.css", "radius.css", "index.css"]
        s.work.tests = .init(passed: 42, failed: nil, ok: true)
        s.work.server = URL(string: "http://localhost:6006")
        s.work.todos = .init(done: 2, total: 5, current: "Auditing colour use")
        s.work.helpers = 2
        s.pr = PullRequest(number: 77, url: URL(string: "https://github.com")!, checks: .running)
        if state == .waiting {
            s.title = "Fix idle rows"
            s.color = "#6AB7D9"
            s.summary = "Run: swift test"
            s.detail = "swift test --filter IdleRowTests"
            s.always = "Bash(swift test:*)"
            s.canAnswer = true
            s.work = Work()
            s.pr = nil
        }
        return s
    }
}

// MARK: General

struct GeneralPane: View {
    let model: NotchModel
    let connection: Connection
    @AppStorage("screen") private var screen = Prefs.ScreenChoice.builtIn.rawValue
    @State private var openAtLogin = LoginItem.isOn
    @State private var focusNeedsAsking = Focus.needsAsking
    @State private var connected = false
    @State private var problem: String?

    var body: some View {
        PaneHeader(title: "General", text: "Where Notch Buddy lives, and its connection to Claude Code.")

        SettingsGroup {
            SettingsRow(label: "Open at login", text: LoginItem.needsApproval ? "Allow it in System Settings first." : nil) {
                if LoginItem.needsApproval { Button("Open System Settings\u{2026}") { SMAppService.openSystemSettingsLoginItems() } }
                Toggle("Open at login", isOn: $openAtLogin).labelsHidden().toggleStyle(.switch)
                    .onChange(of: openAtLogin) { _, on in openAtLogin = LoginItem.set(on) }
            }
            SettingsRow(label: "Show on") {
                Picker("Show on", selection: $screen) {
                    ForEach(Prefs.ScreenChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden().fixedSize()
            }
            SettingsRow(label: "Quiet during Focus", text: "No sounds and no peeking while a Focus is on. Works when \u{201C}Share Focus Status\u{201D} is on in Focus settings.") {
                if focusNeedsAsking {
                    Button("Allow\u{2026}") { Focus.ask { _ in Task { @MainActor in focusNeedsAsking = Focus.needsAsking } } }
                } else {
                    Button("Open Focus Settings\u{2026}") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!)
                    }
                }
            }
        }

        SettingsGroup(title: "Claude Code", footer: "Connecting adds Notch Buddy to Claude Code\u{2019}s settings file. Disconnecting puts the file back exactly as it was.") {
            HStack(spacing: 10) {
                Circle().fill(connected ? NotchView.green : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
                    .padding(3)
                    .background(Circle().fill((connected ? NotchView.green : Color.clear).opacity(0.2)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(connected ? "Connected" : "Not connected").font(.system(size: 13))
                    Text(problem ?? status).font(.system(size: 11.5)).foregroundStyle(problem == nil ? Color.secondary : Color.red)
                }
                Spacer(minLength: 8)
                Button(connected ? "Disconnect" : "Connect") {
                    problem = connected ? connection.disconnect() : connection.connect()
                    connected = connection.isConnected
                }
            }
            .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 7)
            .frame(minHeight: 44)
        }
        .onAppear { connected = connection.isConnected }

        SettingsGroup(title: "Updates") {
            if let update = model.update {
                SettingsRow(label: "Version \(update.version) is available",
                            text: updateText(update)) {
                    if model.updating == .working { ProgressView().controlSize(.small) }
                    else if case .failed = model.updating { Link("Open downloads page", destination: update.page) }
                    else { Button(update.download == nil ? "Download" : "Update now") { model.installUpdate() }.buttonStyle(.borderedProminent) }
                }
            } else {
                SettingsRow(label: "Notch Buddy \(Updater.currentVersion)",
                            text: Updater.feed == nil ? "This copy was built from source, so it doesn\u{2019}t check for updates." : "Up to date. Checks once a day.") { EmptyView() }
            }
        }
    }

    private var status: String {
        guard connected else { return "Notch Buddy can\u{2019}t see your sessions until you connect." }
        guard let heard = model.lastHeard else { return "Waiting to hear from Claude Code." }
        return "Last heard from Claude Code \(heard.formatted(.relative(presentation: .named)))."
    }

    private func updateText(_ update: Updater.Release) -> String {
        if case .failed(let why) = model.updating { return why }
        if model.updating == .working { return "Downloading and installing\u{2026}" }
        return update.download == nil ? "Opens the downloads page." : "Downloads it, installs it and restarts Notch Buddy."
    }
}

// MARK: Look

struct LookPane: View {
    let model: NotchModel
    @AppStorage("clawdColor") private var color = Prefs.clay
    @AppStorage("rightSide") private var rightSide = Prefs.RightSide.auto.rawValue
    @AppStorage("hideFinished") private var hideFinished = false
    @AppStorage("peek") private var peek = true
    @AppStorage("celebrations") private var celebrations = true
    /// What the preview is pretending: Claude working, needing you, done, or nothing running.
    @State private var demo = Session.State.working
    @State private var word = ""
    @State private var run: Task<Void, Never>?

    private var side: Prefs.RightSide { Prefs.RightSide(rawValue: rightSide) ?? .auto }
    private var usageText: String { "\(model.usageLeft ?? 83)%" }

    var body: some View {
        PaneHeader(title: "Look", text: "How Clawd and the closed notch look, and how they behave.")

        NotchPreview(caption: caption) {
            ClosedNotch(mode: demo == .ready ? DayPart.now.clawdMode : Session(id: "", folder: "", state: demo, color: "").clawdMode,
                        color: previewColor, onWord: { said in withAnimation(.snappy) { word = said } }) {
                // Auto's two faces take turns every 6 seconds while Claude works, as in the real notch.
                TimelineView(.periodic(from: .now, by: 6)) { time in
                    let showsUsage = Int(time.date.timeIntervalSinceReferenceDate / 6) % 2 == 1
                    rightSideView(showsUsage: showsUsage)
                        .id("\(demo)\(rightSide)\(showsUsage)")
                        .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button("Play example") { play() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background(Capsule().fill(.black.opacity(0.45)))
                .padding(9)
                .help("Also plays in the real notch")
        }

        SettingsGroup(title: "Clawd") {
            SettingsRow(label: "Colour", text: color == Prefs.random ? "Each session gets its own colour." : nil) {
                HStack(spacing: 9) {
                    ForEach(Prefs.palette, id: \.self) { hex in Swatch(hex: hex, chosen: color == hex) { color = hex } }
                }
            }
            SettingsRow(label: "Random for each session", text: "So you can tell sessions apart at a glance.") {
                Toggle("Random for each session", isOn: Binding(get: { color == Prefs.random }, set: { color = $0 ? Prefs.random : Prefs.clay }))
                    .labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(label: "Clawd reacts", text: "A little animation when tests pass or fail, Claude pushes, a pull request merges, and more.") {
                Toggle("Clawd reacts", isOn: $celebrations).labelsHidden().toggleStyle(.switch)
            }
        }

        SettingsGroup(title: "Closed notch") {
            SettingsRow(label: "Right side shows", text: sideText) {
                Picker("Right side shows", selection: $rightSide) {
                    ForEach(Prefs.RightSide.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            SettingsRow(label: "Peek open", text: "When Claude needs you, and for big news like a merge.") {
                Toggle("Peek open", isOn: $peek).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(label: "Finished sessions") {
                Picker("Finished sessions", selection: $hideFinished) {
                    Text("Stay until I click").tag(false)
                    Text("Hide right away").tag(true)
                }
                .labelsHidden().fixedSize()
            }
        }
        .onDisappear { run?.cancel() }
    }

    /// What the right wing says in the preview, following the real notch's rules.
    @ViewBuilder private func rightSideView(showsUsage: Bool) -> some View {
        let status = word.hasSuffix("\u{2026}") ? word : "Working\u{2026}"
        switch (demo, side) {
        case (.waiting, _):
            Text("Run npm test?").foregroundStyle(Color(red: 0x23 / 255, green: 0x1C / 255, blue: 0))
                .padding(.horizontal, 9).frame(height: 20).background(Capsule().fill(NotchView.amber)).fixedSize()
        case (.working, .word): Text(status).foregroundStyle(NotchView.clay)
        case (.working, .sessions): HStack(spacing: 6) { Spinner(); Text("2").foregroundStyle(NotchView.clay) }
        case (.working, .auto): Text(showsUsage ? usageText : status).foregroundStyle(NotchView.clay)
        case (.done, .word), (.done, .auto): Text("Done!").foregroundStyle(side == .auto ? NotchView.green : NotchView.clay)
        case (_, .usage), (.ready, .auto): Text(usageText).foregroundStyle(NotchView.clay)
        default: EmptyView()
        }
    }

    private var caption: String {
        switch demo {
        case .working: side == .auto ? "Claude is working. Auto swaps every 6 seconds." : "Claude is working"
        case .waiting: "Claude needs you"
        case .done: "A session just finished"
        case .ready: "Nothing running: Clawd\u{2019}s day off"
        }
    }

    private var sideText: String {
        switch side {
        case .auto: "Switches between what Clawd is doing and your usage left."
        case .word: "What Clawd is doing: \u{201C}Smooshing\u{2026}\u{201D}, \u{201C}Done!\u{201D}."
        case .sessions: "How many sessions are busy."
        case .usage: "How much of your 5-hour limit is left."
        }
    }

    /// With the random setting, each state of the example gets another colour, as sessions would.
    private var previewColor: String {
        guard color == Prefs.random else { return color }
        let states: [Session.State] = [.working, .waiting, .done, .ready]
        return Prefs.palette[((states.firstIndex(of: demo) ?? 0) + 2) % Prefs.palette.count]
    }

    /// Works, needs you, finishes, rests: here, and in the real notch.
    private func play() {
        run?.cancel()
        model.playExample()
        run = Task {
            for state in [Session.State.working, .waiting, .done, .ready, .working] {
                withAnimation(.snappy) { demo = state }
                try? await Task.sleep(for: .seconds(2.2))
                if Task.isCancelled { return }
            }
        }
    }
}

// MARK: Sessions

struct RowsPane: View {
    let model: NotchModel
    @AppStorage("groupByProject") private var grouping = Prefs.Grouping.many.rawValue
    private static let previewWidth: CGFloat = 470

    var body: some View {
        let _ = model.prefs   // redraw when a choice changes
        let session = Session.sample()
        let details = session.details(shortcut: false, account: (name: "Work", color: Prefs.clay))
        let lines = NotchModel.detailLines(details, width: Self.previewWidth - 2 * NotchModel.listSide - NotchModel.textInset - 12)
        let detailHeight = lines == 0 ? 0 : CGFloat(lines) * NotchModel.detailLineHeight + NotchModel.detailBottom

        PaneHeader(title: "Sessions", text: "What each session row shows. At a glance is always on the row. On hover waits in the details line.")

        NotchPreview(height: 32 + NotchModel.rowHeight + detailHeight + 46,
                     caption: RowPrefs.always() ? "Details always showing" : "Shown with the mouse over the row", open: true) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 32)
                SessionRow(session: session, color: session.color, now: Date(), account: (name: "Work", color: Prefs.clay, email: nil),
                           hovered: true, details: details, detailHeight: detailHeight)
                    .padding(.horizontal, NotchModel.listSide)
                    .padding(.bottom, NotchModel.listBottom)
            }
            .frame(width: Self.previewWidth)
        }

        Picker("Preset", selection: Binding(get: { RowPrefs.preset()?.rawValue ?? "custom" },
                                            set: { if let preset = RowPrefs.Preset(rawValue: $0) { RowPrefs.apply(preset) } })) {
            ForEach(RowPrefs.Preset.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            // Custom is where you end up, not something to pick.
            if RowPrefs.preset() == nil { Text("Custom").tag("custom") }
        }
        .pickerStyle(.segmented).labelsHidden()

        ForEach(RowPrefs.groups, id: \.title) { group in
            SettingsGroup(title: group.title) {
                ForEach(group.pieces, id: \.self) { piece in
                    SettingsRow(label: piece.title, text: piece.example) {
                        Picker(piece.title, selection: Binding(get: { RowPrefs.place(piece) }, set: { RowPrefs.set(piece, $0) })) {
                            ForEach(RowPlace.allCases.filter { $0 != .glance || piece.hasGlance }, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }
        }

        SettingsGroup {
            SettingsRow(label: "Group by project", text: "Sessions in the same folder sit under its name. Click the name to fold them away.") {
                Picker("Group by project", selection: $grouping) {
                    ForEach(Prefs.Grouping.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden().fixedSize()
            }
            SettingsRow(label: "Always show details", text: "Without hovering. Rows get taller.") {
                Toggle("Always show details", isOn: Binding(get: { RowPrefs.always() }, set: { RowPrefs.setAlways($0) }))
                    .labelsHidden().toggleStyle(.switch)
            }
        }
    }
}

// MARK: Sounds

struct SoundsPane: View {
    var body: some View {
        PaneHeader(title: "Sounds", text: "One sound for each moment worth hearing. All of them stay quiet while a Focus is on.")
        SettingsGroup(footer: "These are your Mac\u{2019}s own alert sounds, the same ones System Settings offers. Picking one plays it.") {
            ForEach(Prefs.Moment.allCases, id: \.self) { moment in
                SettingsRow(label: moment.title) { SoundPicker(moment: moment).labelsHidden().fixedSize() }
            }
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

// MARK: Shortcuts

struct ShortcutsPane: View {
    @AppStorage("shortcuts") private var shortcuts = true

    var body: some View {
        let session = Session.sample(.waiting)
        let lines = session.commandLines()

        PaneHeader(title: "Shortcuts", text: "Answer Claude from the keyboard, in any app, without opening the notch.")

        NotchPreview(height: 32 + NotchModel.Card.height(commandLines: lines) + 34, open: true) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 32)
                RequestCard(session: session, color: session.color, now: Date(), commandLines: lines,
                            details: shortcuts ? [.keys] : [], detailHeight: shortcuts ? 22 : 0, answer: { _ in }, open: {})
                    .padding(.horizontal, NotchModel.listSide)
                    .allowsHitTesting(false)
            }
            .frame(width: 470)
        }

        SettingsGroup {
            SettingsRow(label: "Keyboard shortcuts", text: "They answer the request at the top of the notch.") {
                Toggle("Keyboard shortcuts", isOn: $shortcuts).labelsHidden().toggleStyle(.switch)
            }
            SettingsRow(label: "Allow") { HStack(spacing: 5) { Keycap(key: "\u{2325}"); Keycap(key: "\u{2318}"); Keycap(key: "Y") } }
            SettingsRow(label: "Deny") { HStack(spacing: 5) { Keycap(key: "\u{2325}"); Keycap(key: "\u{2318}"); Keycap(key: "N") } }
        }
        .opacity(1)
    }
}

// MARK: About

struct AboutPane: View {
    let model: NotchModel
    @State private var hobby: String?

    var body: some View {
        VStack(spacing: 6) {
            ClawdView(mode: "life", color: model.restingColor, onHobby: { hobby = $0 })
                .frame(width: 168, height: 109)
                .frame(width: 210, height: 136)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black))
            Text("Notch Buddy").font(.system(size: 20, weight: .bold)).padding(.top, 12)
            Text("Version \(Updater.currentVersion)").font(.system(size: 12)).foregroundStyle(.secondary)
            Text(hobby.flatMap { DayPart.status[$0] } ?? "Clawd shows what Claude Code is doing, right in your notch.")
                .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 6)
                .id(hobby).transition(.opacity).animation(.easeInOut(duration: 0.3), value: hobby)
            HStack(spacing: 8) {
                Link("Release notes", destination: URL(string: "https://github.com/theposch/notch-buddy/releases/latest")!)
                Link("GitHub", destination: URL(string: "https://github.com/theposch/notch-buddy")!)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: Shared pieces

/// One colour to pick.
struct Swatch: View {
    let hex: String
    let chosen: Bool
    let pick: () -> Void

    var body: some View {
        Button(action: pick) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.black.opacity(0.14), lineWidth: 0.5))
                .overlay(Circle().stroke(Color(hex: hex), lineWidth: chosen ? 2 : 0).padding(-3.5))
        }
        .buttonStyle(.plain)
        .help(hex)
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

/// The window around the settings. There's only ever one. Its sidebar runs up under the title bar,
/// the way System Settings does.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    static let size = NSSize(width: 880, height: 660)

    func show(model: NotchModel) {
        if window == nil {
            let page = NSHostingController(rootView: SettingsView(model: model, connection: Connection()))
            page.sizingOptions = []
            let window = NSWindow(contentViewController: page)
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.title = "Notch Buddy Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            // The page fills the whole window, title bar included.
            window.setContentSize(Self.size)
            window.contentMinSize = Self.size
            window.contentMaxSize = Self.size
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
