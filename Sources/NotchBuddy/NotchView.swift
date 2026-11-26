import AppKit
import SwiftUI

/// The black notch: Clawd in the left wing and the right-side option in the right one when closed.
/// Open: usage left, settings and Quit along the top, then one row per Claude Code session.
struct NotchView: View {
    let model: NotchModel
    let actions: NotchActions

    static let clay = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    // Status colours are the Mac's own, as they look in dark appearance (the notch is always dark).
    static let amber = Color(red: 1, green: 0xD6 / 255, blue: 0x0A / 255)
    static let green = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let orange = Color(red: 1, green: 0x9F / 255, blue: 0x0A / 255)
    static let red = Color(red: 1, green: 0x45 / 255, blue: 0x3A / 255)
    static let purple = Color(red: 0xBF / 255, green: 0x5A / 255, blue: 0xF2 / 255)
    static let dim = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x95 / 255)
    /// Text on the black notch, as the Mac ranks it: what matters, what supports it, what's nearly a whisper.
    static let secondary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.62)
    static let tertiary = Color(red: 235 / 255, green: 235 / 255, blue: 245 / 255).opacity(0.34)
    static let hairline = Color(red: 84 / 255, green: 84 / 255, blue: 88 / 255).opacity(0.62)
    /// What sits on the black: a pressed-in fill for buttons, a faint one under the mouse, a card.
    static let fill = Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.36)
    static let faintFill = Color(red: 118 / 255, green: 118 / 255, blue: 128 / 255).opacity(0.15)
    static let card = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)

    /// Orange under 20% left, red under 10%.
    static func usageColor(_ left: Int, normal: Color) -> Color {
        left < 10 ? red : left < 20 ? orange : normal
    }

    var body: some View {
        let g = model.geometry
        let open = model.isOpen
        let size = open ? model.openSize : model.closedSize
        let radius = open ? NotchGeometry.openRadius : NotchGeometry.closedRadius
        let shoulder = open ? NotchGeometry.openShoulder : NotchGeometry.closedShoulder
        let wing = model.wingWidth

        ZStack(alignment: .top) {
            NotchShape(shoulder: shoulder, corner: radius)
                .fill(.black)
                .frame(width: size.width + 2 * shoulder, height: size.height)
                .contextMenu {
                    Button("Settings…", action: actions.settings)
                    Button("Quit Notch Buddy", action: actions.quit)
                }

            if open {
                Group {
                    if model.welcome { welcome } else { panel }
                }
                .frame(width: size.width, height: size.height - g.barHeight, alignment: .top)
                .padding(.top, g.barHeight)
                .transition(.growIn)

                if !model.welcome {
                    topBar
                        .frame(width: size.width, height: g.barHeight)
                        .transition(.growIn)
                }
            }

            HStack(spacing: 0) {
                // Clawd in the left wing, always at its outer edge.
                ClawdView(mode: model.welcome ? "waiting" : model.clawdMode, color: model.clawdColor, onWord: { word in
                    withAnimation(.spring(duration: 0.32, bounce: 0.18)) { model.clawdWord = word }
                }, onHobby: { model.hobby = $0 }, step: model.lead?.activity, reaction: model.reaction)
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: wing, height: g.barHeight, alignment: .leading)

                Spacer(minLength: g.cameraWidth)

                HStack(spacing: 6) {
                    if model.showsSpinner { Spinner() }
                    // Several accounts: whose usage this is.
                    if model.rightIsUsage, model.severalAccounts, let account = model.followed {
                        AccountDot(color: account.color(among: model.accounts))
                    }
                    Text(model.rightText ?? "")
                        .font(Font(NotchModel.wingFont))
                        .foregroundStyle(rightColor)
                        .lineLimit(1)
                        .fixedSize()
                        .contentTransition(.numericText())
                        .padding(.horizontal, model.needsLine != nil ? 9 : 0)
                        .frame(height: 20)
                        .background { if model.needsLine != nil { Capsule().fill(Self.amber) } }
                        // Fade between words; numbers (usage left) roll instead.
                        .id(model.rightIsUsage ? "usage" : model.rightText)
                        .transition(.opacity)
                        .animation(.snappy, value: model.rightText)
                }
                .frame(width: wing, height: g.barHeight)
            }
            .frame(width: model.closedSize.width)
            .opacity(open ? 0 : 1)
            .allowsHitTesting(false)
        }
        // Everything stays inside the black shape while it grows and shrinks.
        .mask(alignment: .top) {
            NotchShape(shoulder: shoulder, corner: radius)
                .frame(width: size.width + 2 * shoulder, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var rightColor: Color {
        if model.needsLine != nil { return Color(red: 0x23 / 255, green: 0x1C / 255, blue: 0) }   // dark on the yellow pill
        if model.outLine != nil { return Self.dim }
        if let shown = model.shown { return shown.color }
        if model.rightIsUsage, let left = model.usageLeft { return Self.usageColor(left, normal: Self.clay) }
        return Self.clay
    }

    // MARK: Open

    private var panel: some View { rows }

    /// The menu bar strip, either side of the camera: usage left, then settings and Quit.
    private var topBar: some View {
        HStack(spacing: 6) {
            // Usage left, per account: a ring in the account's colour and the number.
            // Whose it is, when it resets and the week are on hover.
            HStack(spacing: NotchModel.usageGap) {
                ForEach(model.shownAccounts) { account in
                    if let left = account.left {
                        HStack(spacing: 6) {
                            Ring(fraction: Double(left) / 100, color: Color(hex: account.color(among: model.accounts)), size: NotchModel.usageRing, line: 2)
                            Text("\(left)%")
                                .contentTransition(.numericText())
                                .animation(.snappy, value: left)
                                .foregroundStyle(Self.usageColor(left, normal: .white))
                        }
                        .help(model.severalAccounts ? "\(account.name): \(account.summary)" : account.summary)
                    }
                }
            }
            // A login is switched on but macOS wants your OK first: say so, with the button that asks.
            if let hint = model.usageHint(short: model.shortUsageStrip) {
                if let text = hint.text { Text(text).foregroundStyle(Self.amber).fixedSize().padding(.trailing, 2) }
                Button(hint.button) { model.allowUsage() }
                    .buttonStyle(SmallPill(fill: Self.amber))
                    .help("macOS asks whether Notch Buddy may read the login. Choose \u{201C}Always Allow\u{201D}.")
            }
            // Leave the camera clear on a MacBook; other screens have nothing to avoid.
            Spacer(minLength: model.geometry.hasNotch ? model.geometry.cameraWidth + 16 : 16)
            if let update = model.update { UpdateButton(model: model, update: update) }
            HeaderButton(symbol: "gearshape", help: "Settings", action: actions.settings)
            HeaderButton(symbol: "power", help: "Quit Notch Buddy", action: actions.quit)
        }
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .padding(.horizontal, 18)
    }

    @ViewBuilder private var rows: some View {
        if model.sessions.isEmpty {
            allCaughtUp
        } else {
            // Redraw every second so the working time keeps counting.
            TimelineView(.periodic(from: .now, by: 1)) { time in
                let width = model.openWidth
                let shown = Array(model.rows.prefix(NotchModel.maxRows))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, session in
                        let hovered = model.hovered == session.id
                        let account = model.severalAccounts ? model.account(of: session).map { (name: $0.name, color: $0.color(among: model.accounts), email: $0.email) } : nil
                        let details = model.showsDetails(session) ? model.details(for: session, now: time.date) : []
                        let detailHeight = model.detailHeight(of: session, width: width)
                        Group {
                            if session.state == .waiting {
                                RequestCard(session: session, color: model.color(of: session), now: time.date, account: account,
                                            commandLines: session.commandLines(perLine: NotchModel.Card.charactersPerLine(width: width)),
                                            details: details, detailHeight: detailHeight,
                                            answer: { choice in withAnimation { model.answer(session, choice) } },
                                            open: { withAnimation { model.open(session) } })
                            } else {
                                // A hairline between rows, but not beside the one under the mouse or under a card.
                                let above = index > 0 ? shown[index - 1] : nil
                                SessionRow(session: session, color: model.color(of: session), now: time.date, account: account,
                                           hovered: hovered, details: details, detailHeight: detailHeight,
                                           divider: above != nil && above?.state != .waiting && !hovered && model.hovered != above?.id)
                            }
                        }
                        .modifier(Stagger(index: index))
                        .onTapGesture { withAnimation { model.open(session) } }
                        .contextMenu { RowMenu(session: session, clear: { withAnimation { model.clear(session) } }) }
                        .onHover { inside in
                            withAnimation(.easeOut(duration: 0.15)) {
                                if inside { model.hovered = session.id }
                                else if model.hovered == session.id { model.hovered = nil }
                            }
                        }
                    }
                }
                .padding(.horizontal, NotchModel.listSide)
                .padding(.top, NotchModel.listTop)
            }
        }
    }

    /// Nothing running: a bigger Clawd doing what suits the time of day.
    private var allCaughtUp: some View {
        TimelineView(.everyMinute) { time in
            let part = DayPart(hour: Calendar.current.component(.hour, from: time.date))
            let napping = model.usageOut
            let line = napping ? "Usage is used up. Back at \(model.resetTime ?? "reset"), fully rested." : part.line(for: model.hobby)
            VStack(spacing: 0) {
                ClawdView(mode: napping ? "out" : part.clawdMode, color: model.restingColor, follow: napping ? nil : model.hobby)
                    .frame(width: 74, height: 48)
                Text(napping ? "Clawd\u{2019}s napping" : "All caught up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(Self.dim)
                    .padding(.top, 3)
                    .id(line)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: line)
                if !napping, let recap = model.today.line {
                    Text(recap)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Self.dim.opacity(0.75))
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)   // room to breathe above the bottom edge
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(Stagger(index: 0))
        }
    }

    /// First launch: hello, and one button.
    private var welcome: some View {
        VStack(spacing: 10) {
            Text("Hi, I'm Clawd")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("I'll show what Claude Code is doing, right here in your notch,\nand you can answer its questions from here.")
                .font(.system(size: 12))
                .foregroundStyle(Self.dim)
                .multilineTextAlignment(.center)
            Button("Connect to Claude Code", action: actions.connect)
                .buttonStyle(Pill(fill: Self.clay, text: .black))
                .padding(.top, 4)
        }
        .padding(.top, 14)
    }
}

/// What the notch's buttons and menu do.
struct NotchActions {
    var settings: () -> Void
    var quit: () -> Void
    var connect: () -> Void
}

/// A small icon button in the panel's top bar.
struct HeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hover ? .white : NotchView.dim)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// "Update" in the top strip when a newer version is out: one click downloads it, installs it
/// and restarts. A spinner while it does; a warning if it couldn't (click for the downloads page).
struct UpdateButton: View {
    let model: NotchModel
    let update: Updater.Release

    var body: some View {
        switch model.updating {
        case .idle:
            Button("Update") { model.installUpdate() }
                .buttonStyle(SmallPill(fill: NotchView.clay))
                .help("Install version \(update.version) and restart Notch Buddy")
        case .working:
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)
                .frame(width: 22, height: 22)
                .help("Installing version \(update.version)\u{2026}")
        case .failed(let why):
            Button { model.installUpdate() } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NotchView.amber)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(why) Click to open the downloads page.")
        }
    }
}

/// A small rounded button for the top strip.
struct SmallPill: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font(NotchModel.smallButtonFont))
            .foregroundStyle(.black)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(Capsule().fill(fill.opacity(configuration.isPressed ? 0.7 : 1)))
            .contentShape(Capsule())
            .fixedSize()
    }
}

/// Shown with the "Sessions" option while something is working.
struct Spinner: View {
    /// The little star Claude Code shows in Terminal while it works: it grows from a dot
    /// to a full star and back. (\u{FE0E} keeps ✳ a plain character instead of an emoji.)
    static let frames = ["·", "✢", "✳\u{FE0E}", "✶", "✻", "✽", "✻", "✶", "✳\u{FE0E}", "✢"]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.12) % Self.frames.count
            Text(Self.frames[step])
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchView.clay)
                .frame(width: 14, height: 14)
        }
    }
}

/// One session: Clawd, its name and one line saying what it's doing. Whatever you chose to see
/// "at a glance" sits at the end; the rest waits in the details line (Settings > Sessions).
struct SessionRow: View {
    let session: Session
    let color: String
    let now: Date
    /// Its account's name and colour, when you have several.
    var account: (name: String, color: String, email: String?)? = nil
    /// The mouse is over it.
    var hovered = false
    /// The details line, when it's showing, and how tall it is.
    var details: [Detail] = []
    var detailHeight: CGFloat = 0
    /// A hairline above it.
    var divider = false
    /// What this row's Clawd says he's doing ("Sautéing…"), matching his animation.
    @State private var word = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RowClawd(session: session, color: color, word: $word)
                VStack(alignment: .leading, spacing: 1) {
                    RowTitle(session: session, account: account)
                    statusLine
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Glance(session: session, now: now)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .frame(height: NotchModel.rowHeight)
            .overlay(alignment: .bottom) {
                if RowPrefs.place(.todo) == .glance, session.state == .working, let todos = session.work.todos {
                    TodoLine(todos: todos).padding(.leading, NotchModel.textInset).padding(.trailing, 12).padding(.bottom, 3)
                }
            }

            if detailHeight > 0 {
                DetailsLine(details: details)
                    .padding(.leading, NotchModel.textInset)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: detailHeight, alignment: .top)
                    .offset(y: -4)
                    .transition(.opacity)
            }
        }
        .opacity(session.state == .done && !hovered ? 0.78 : 1)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(NotchView.faintFill.opacity(hovered ? 1 : 0)))
        .overlay(alignment: .top) {
            Rectangle().fill(NotchView.hairline).frame(height: 0.5)
                .padding(.leading, NotchModel.textInset).padding(.trailing, 12)
                .opacity(divider ? 1 : 0)
        }
        .contentShape(Rectangle())
        .help((session.title == nil ? "" : "In \(session.folder). ") + (session.state == .done ? "Click to open and clear" : "Click to open"))
    }

    /// The one line under the name: what just happened, what Claude is doing, or how it ended.
    @ViewBuilder private var statusLine: some View {
        if let notice = session.notice {
            HStack(spacing: 6) {
                Text(notice.word).foregroundStyle(notice.color).fontWeight(.medium).fixedSize()
                if let detail = notice.detail { Text(detail).foregroundStyle(NotchView.secondary) }
            }
            .transition(.opacity)
        } else {
            switch session.state {
            case .working:
                // What Claude is doing right now; before its first step, Clawd's own word for it.
                if let activity = session.activity { Text(activity).foregroundStyle(NotchView.secondary).id(activity).transition(.opacity) }
                else { Text(word.hasSuffix("…") ? word : "Working").foregroundStyle(NotchView.clay) }
            case .done:
                if let problem = session.problem { Text(problem).foregroundStyle(NotchView.red) }
                else if let said = session.lastWords { Text("\u{201C}\(said)\u{201D}").foregroundStyle(NotchView.secondary) }
                else { Text("Done").foregroundStyle(NotchView.green) }
            case .ready:
                Text("Ready").foregroundStyle(NotchView.secondary)
            case .waiting:
                Text(session.summary ?? "Needs you").foregroundStyle(NotchView.amber)
            }
        }
    }

    /// "42s", "12m", "1h 05m"
    static func elapsed(_ date: Date, now: Date) -> String { Session.elapsed(date, now: now) }
    /// "now", "4m", "2h", "3d"
    static func ago(_ date: Date, now: Date) -> String { Session.ago(date, now: now) }
}

/// A session that needs you, as a card: what it wants, the whole command, and the answers.
struct RequestCard: View {
    let session: Session
    let color: String
    let now: Date
    var account: (name: String, color: String, email: String?)? = nil
    /// How many lines of the command to show (0: there's nothing to show).
    let commandLines: Int
    var details: [Detail] = []
    var detailHeight: CGFloat = 0
    let answer: (NotchModel.Answer) -> Void
    /// "Review plan", "Open conversation": go to it.
    let open: () -> Void
    @State private var word = ""

    private typealias Card = NotchModel.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RowClawd(session: session, color: color, word: $word)
                VStack(alignment: .leading, spacing: 1) {
                    RowTitle(session: session, account: account)
                    Text(wants).font(.system(size: 12)).foregroundStyle(NotchView.amber).lineLimit(1)
                }
                Spacer(minLength: 8)
                Glance(session: session, now: now)
            }
            .frame(height: Card.header)

            if commandLines > 0, let command = session.detail {
                (Text(session.summary?.hasPrefix("Run") == true ? "$ " : "").foregroundColor(NotchView.tertiary) + Text(command))
                    .font(Font(Card.commandFont))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(commandLines)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: Card.commandHeight(lines: commandLines) - 2 * Card.commandPad, alignment: .topLeading)
                    .padding(.vertical, Card.commandPad)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.black))
                    .padding(.top, Card.gap)
                    .help(session.canAnswer && session.always != nil ? "Always allow would allow \(session.always ?? "")" : command)
            }

            HStack(spacing: 6) {
                if session.plan {
                    Button("Review plan", action: open).buttonStyle(CardButton(prominent: true))
                } else if session.canAnswer {
                    Button("Deny") { answer(.deny) }.buttonStyle(CardButton())
                    if let always = session.always {
                        Button("Always allow") { answer(.always) }.buttonStyle(CardButton()).help("Always allows \(always)")
                    }
                    Button("Allow") { answer(.allow) }.buttonStyle(CardButton(prominent: true))
                } else {
                    // A question, or a request the notch can't answer from here: go to the conversation.
                    Button("Open conversation", action: open).buttonStyle(CardButton())
                }
            }
            .frame(height: Card.button)
            .padding(.top, Card.gap)

            if detailHeight > 0 {
                DetailsLine(details: details)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: detailHeight, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .padding(Card.pad)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NotchView.card))
        .padding(.horizontal, Card.margin)
        .padding(.top, Card.margin)
        .padding(.bottom, Card.below)
        .contentShape(Rectangle())
        .help("Click to open")
    }

    /// "Wants to run a command", "Has a question", "Plan ready to review".
    private var wants: String {
        guard let summary = session.summary else { return "Needs you" }
        if session.plan || summary == "Has a question" { return summary }
        if summary.hasPrefix("Run") { return "Wants to run a command" }
        return "Wants to: " + summary.prefix(1).lowercased() + summary.dropFirst()
    }
}

/// Clawd on a row, with "+2" on him while Claude's helpers are at work (when you show that at a glance).
struct RowClawd: View {
    let session: Session
    let color: String
    @Binding var word: String

    var body: some View {
        ClawdView(mode: session.clawdMode, color: color, onWord: { said in
            withAnimation(.easeInOut(duration: 0.25)) { word = said }
        }, step: session.activity, reaction: Prefs.celebrations ? session.notice : nil)
        .frame(width: 60, height: 39)
        .overlay(alignment: .bottomTrailing) {
            if RowPrefs.place(.helpers) == .glance, session.work.helpers > 0 { HelperBadge(count: session.work.helpers).offset(x: -8, y: -4) }
        }
    }
}

/// A row's name, and its model and account as small tags when you show those at a glance.
struct RowTitle: View {
    let session: Session
    var account: (name: String, color: String, email: String?)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(session.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if RowPrefs.place(.model) == .glance, let model = session.model { ModelBadge(name: model) }
            if RowPrefs.place(.account) == .glance, let account {
                AccountChip(name: account.name, color: account.color).help(account.email ?? account.name)
            }
        }
    }
}

/// The end of a row: the small things you chose to always see. Cost, how the tests went, the pull
/// request, the time, and a ring for how full the conversation is (a green tick once it's done).
struct Glance: View {
    let session: Session
    let now: Date

    var body: some View {
        HStack(spacing: 9) {
            if RowPrefs.place(.cost) == .glance, let cost = session.cost {
                Text(Detail.cost(cost).text).foregroundStyle(NotchView.tertiary)
            }
            if RowPrefs.place(.tests) == .glance, let tests = session.work.tests {
                Image(systemName: Symbols.tests)
                    .foregroundStyle(tests.ok ? NotchView.green : NotchView.red)
                    .help(tests.text)
            }
            if RowPrefs.place(.pullRequest) == .glance, let pr = session.pr {
                Image(systemName: Symbols.pullRequest)
                    .foregroundStyle(Outcome.color(pr))
                    .help(pr.text)
            }
            if RowPrefs.place(.time) == .glance {
                Text(session.timeText(now: now))
                    .foregroundStyle(NotchView.tertiary)
                    .contentTransition(.numericText())
            }
            if session.state == .done, session.problem == nil {
                Image(systemName: Symbols.done).font(.system(size: 16)).foregroundStyle(NotchView.green)
            } else if session.state != .waiting, RowPrefs.place(.context) == .glance, let used = session.context {
                Ring(fraction: Double(used) / 100, color: used >= 90 ? NotchView.red : used >= 80 ? NotchView.orange : .white, size: 18, line: 2.25)
                    .help("\(used)% of context used")
            }
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .fixedSize()
    }
}

/// The symbols rows use, in one place (a test checks that this Mac has them all).
enum Symbols {
    static let tests = "flask"
    static let pullRequest = "arrow.triangle.pull"
    static let branch = "arrow.triangle.branch"
    static let server = "arrow.up.right.square"
    static let todo = "checklist"
    static let done = "checkmark.circle.fill"
    static let all = [tests, pullRequest, branch, server, todo, done]
}

/// A thin ring that fills clockwise from the top: usage left, or how full a conversation is.
struct Ring: View {
    let fraction: Double
    let color: Color
    var size: CGFloat = 18
    var line: CGFloat = 2.25

    var body: some View {
        ZStack {
            Circle().stroke(NotchView.fill.opacity(0.7), lineWidth: line)
            Circle().trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(line / 2)
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }
}

/// A wide button on a request's card.
struct CardButton: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(prominent ? Color(red: 0x1D / 255, green: 0x0E / 255, blue: 0x07 / 255) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: NotchModel.Card.button)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(prominent ? NotchView.clay : NotchView.fill)
                .brightness(configuration.isPressed ? -0.08 : 0))
            .contentShape(Rectangle())
    }
}

/// Right-click on a row: open its folder, copy what Claude last ran, open its pull request or server.
struct RowMenu: View {
    let session: Session
    let clear: () -> Void

    var body: some View {
        if let folder = session.place.folder {
            let url = URL(fileURLWithPath: folder)
            Button("Open in Terminal") {
                NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                        configuration: NSWorkspace.OpenConfiguration())
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        if let command = session.work.lastCommand {
            Button("Copy Last Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }
        }
        if session.pr != nil || session.work.server != nil { Divider() }
        if let pr = session.pr { Button("Open Pull Request #\(pr.number)") { NSWorkspace.shared.open(pr.url) } }
        if let server = session.work.server { Button("Open \(Detail.server(server).text)") { NSWorkspace.shared.open(server) } }
        Divider()
        Button("Clear from List", action: clear)
    }
}

/// Small symbols at the end of a row's second line: how the last tests went (✓ or ✕)
/// and the pull request, coloured by its checks. Words for them are in the details line.
struct Outcome: View {
    let tests: Work.Tests?
    let pr: PullRequest?

    var body: some View {
        HStack(spacing: 5) {
            if let tests {
                Image(systemName: tests.ok ? "checkmark" : "xmark")
                    .foregroundStyle(tests.ok ? NotchView.green : NotchView.red)
                    .help(tests.text)
            }
            if let pr {
                Image(systemName: "arrow.triangle.pull")
                    .foregroundStyle(Self.color(pr))
                    .help(pr.text)
            }
        }
        .font(.system(size: 10, weight: .bold))
        .fixedSize()
    }

    static func color(_ pr: PullRequest) -> Color {
        if pr.merged { return NotchView.purple }
        switch pr.checks {
        case .passed: return NotchView.green
        case .failed: return NotchView.red
        case .running: return NotchView.amber
        case .none: return NotchView.dim
        }
    }
}

/// "+2" on Clawd while Claude's helpers are at work.
struct HelperBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .background(Capsule().fill(Color(white: 0.24)))
            .overlay(Capsule().stroke(.black, lineWidth: 1.5))
            .offset(x: 6, y: 5)
            .help("\(count) helper\(count == 1 ? "" : "s") at work")
    }
}

/// Claude's to-do list as a thin line along the bottom of the row, filling as steps get done.
struct TodoLine: View {
    let todos: Work.Todos

    var body: some View {
        GeometryReader { space in
            Capsule().fill(Color(white: 0.14))
                .overlay(alignment: .leading) {
                    Capsule().fill(NotchView.clay)
                        .frame(width: space.size.width * CGFloat(todos.done) / CGFloat(max(1, todos.total)))
                }
        }
        .frame(height: 2)
        .animation(.easeOut(duration: 0.4), value: todos.done)
        .help("\(todos.done) of \(todos.total) done" + (todos.current.map { " · \($0)" } ?? ""))
    }
}

/// The details line that slides in on hover. Wraps onto a second line when it has to.
struct DetailsLine: View {
    let details: [Detail]

    var body: some View {
        Flow(spacing: 10, lineSpacing: 3) {
            ForEach(details, id: \.self) { piece($0) }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(NotchView.dim)
        .padding(.top, 2)
    }

    @ViewBuilder private func piece(_ detail: Detail) -> some View {
        switch detail {
        case .keys:
            Text(detail.text).foregroundStyle(.white.opacity(0.75))
        case .branch(let name):
            Item(name, symbol: Symbols.branch)
        case .lines(let text):
            Self.colored(text)
        case .tests(let tests):
            Item(tests.text, symbol: Symbols.tests)
                .foregroundStyle(tests.ok ? NotchView.green : NotchView.red)
        case .pullRequest(let pr):
            Button { NSWorkspace.shared.open(pr.url) } label: { Item(pr.text, symbol: Symbols.pullRequest) }
                .buttonStyle(.plain)
                .foregroundStyle(Outcome.color(pr))
        case .server(let url):
            Button { NSWorkspace.shared.open(url) } label: { Item(detail.text, symbol: Symbols.server) }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.54, green: 0.71, blue: 0.97))
        case .todo(let text):
            Item(text, symbol: Symbols.todo)
        case .account(let name, let color):
            HStack(spacing: 4) { AccountDot(color: color); Text(name) }
        case .cost, .helpers, .model, .context, .time:
            Text(detail.text)
        }
    }

    /// "+212 −38 · 7 files" with the numbers in green and red.
    static func colored(_ text: String) -> Text {
        let parts = text.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return Text(text) }
        return Text(parts[0]).foregroundColor(NotchView.green) + Text(" ") + Text(parts[1]).foregroundColor(NotchView.red)
            + Text(" " + parts[2])
    }
}

/// A small symbol and its words, closer together than a Label puts them.
struct Item: View {
    let text: String
    let symbol: String

    init(_ text: String, symbol: String) {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            Text(text)
        }
    }
}

/// Lays its pieces out left to right, starting a new line when the next one doesn't fit.
struct Flow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].items.append(i)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(([i], size.width, size.height))
            }
        }
        return rows
    }
}

/// The model in a quiet little capsule next to the session's name: "Opus 5.5".
/// The little coloured dot that marks an account.
struct AccountDot: View {
    let color: String
    var body: some View { Circle().fill(Color(hex: color)).frame(width: 6, height: 6) }
}

/// "● Studio" next to a session's model, when you have several accounts.
struct AccountChip: View {
    let name: String
    let color: String

    var body: some View {
        HStack(spacing: 4) {
            AccountDot(color: color)
            Text(name)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(NotchView.dim)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color(white: 0.16)))
        .fixedSize()
    }
}

struct ModelBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(NotchView.dim)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color(white: 0.16)))
            .fixedSize()
    }
}

/// A small rounded button for Allow and Deny.
struct Pill: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Capsule().fill(fill.opacity(configuration.isPressed ? 0.7 : 1)))
            .contentShape(Capsule())
    }
}

/// How full a conversation is: "53%" and a thin bar, like Claude's own context meter.
/// Orange from 80% used, red from 90%, when Claude will soon summarise older messages.
struct ContextMeter: View {
    let used: Int

    var body: some View {
        HStack(spacing: 7) {
            Text("\(used)%")
                .contentTransition(.numericText())
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(NotchView.dim)
            Capsule()
                .fill(Color(white: 0.18))
                .frame(width: 44, height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(fill).frame(width: max(4, 44 * CGFloat(used) / 100))
                }
        }
        .help("\(used)% of context used")
        .animation(.easeOut(duration: 0.3), value: used)
    }

    private var fill: Color {
        used >= 90 ? NotchView.red : used >= 80 ? NotchView.orange : Color(white: 0.6)
    }
}
