import AppKit
import SwiftUI

/// The black notch: Clawd in the left wing and the right-side option in the right one when closed.
/// Open: usage left, settings and Quit along the top, then one row per Claude Code session.
struct NotchView: View {
    let model: NotchModel
    let actions: NotchActions

    static let clay = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    static let amber = Color(red: 0xE8 / 255, green: 0xC6 / 255, blue: 0x6A / 255)
    static let green = Color(red: 0x8F / 255, green: 0xBF / 255, blue: 0x6A / 255)
    static let orange = Color(red: 0xF0 / 255, green: 0x9A / 255, blue: 0x3E / 255)
    static let red = Color(red: 0xE5 / 255, green: 0x48 / 255, blue: 0x4D / 255)
    static let purple = Color(red: 0.71, green: 0.54, blue: 0.88)
    static let dim = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x95 / 255)

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
                // Clawd in the left wing. On the MacBook he sits against the camera;
                // on other screens, at the outer edge.
                ClawdView(mode: model.welcome ? "waiting" : model.clawdMode, color: model.clawdColor, onWord: { word in
                    withAnimation(.spring(duration: 0.32, bounce: 0.18)) { model.clawdWord = word }
                }, onHobby: { model.hobby = $0 }, step: model.lead?.activity, reaction: model.reaction)
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: wing, height: g.barHeight, alignment: g.hasNotch ? .trailing : .leading)

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
        if model.needsLine != nil { return Self.amber }
        if model.outLine != nil { return Self.dim }
        if let shown = model.shown { return shown.color }
        if model.rightIsUsage, let left = model.usageLeft { return Self.usageColor(left, normal: Self.clay) }
        return Self.clay
    }

    // MARK: Open

    private var panel: some View {
        rows
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }

    /// The menu bar strip, either side of the camera: usage left, then settings and Quit.
    private var topBar: some View {
        HStack(spacing: 6) {
            if model.severalAccounts {
                // Every account: dot, name, 5 hours left. Hover for the week.
                ForEach(model.shownAccounts) { account in
                    if let left = account.left {
                        HStack(spacing: 5) {
                            AccountDot(color: account.color(among: model.accounts))
                            if !model.shortUsageStrip { Text(account.name).foregroundStyle(Self.dim).fixedSize() }
                            Text("\(left)%").foregroundStyle(Self.usageColor(left, normal: .white))
                        }
                        .padding(.trailing, 6)
                        .help(account.summary)
                    }
                }
            } else if let left = model.usageLeft, let resets = model.usage?.resets {
                let time = resets.formatted(date: .omitted, time: .shortened)
                Text("\(left)% left")
                    .contentTransition(.numericText())
                    .animation(.snappy, value: left)
                    .foregroundStyle(Self.usageColor(left, normal: .white))
                    .help("Resets \(time)")
                if !model.shortUsageStrip { Text("resets \(time)").foregroundStyle(Self.dim) }
            }
            if !model.severalAccounts, let week = model.weekLeft {
                Text("· week").foregroundStyle(Self.dim)
                Text("\(week)% left")
                    .contentTransition(.numericText())
                    .foregroundStyle(Self.usageColor(week, normal: .white))
            }
            // Leave the camera clear on a MacBook; other screens have nothing to avoid.
            Spacer(minLength: model.geometry.hasNotch ? model.geometry.cameraWidth + 16 : 16)
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
                VStack(spacing: 0) {
                    ForEach(Array(model.rows.prefix(NotchModel.maxRows).enumerated()), id: \.element.id) { index, session in
                        SessionRow(session: session, color: model.color(of: session), now: time.date,
                                   account: model.severalAccounts ? model.account(of: session).map { ($0.name, $0.color(among: model.accounts)) } : nil,
                                   expanded: model.hovered == session.id,
                                   details: session.details(shortcut: session.id == model.shortcutTarget?.id),
                                   answer: { choice in withAnimation { model.answer(session, choice) } },
                                   review: { withAnimation { model.open(session) } })
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

/// Clawd, project name, status and how long ago it changed.
/// When Claude is asking for permission: what it wants to do, with Allow and Deny.
struct SessionRow: View {
    let session: Session
    let color: String
    let now: Date
    /// Its account's name and colour, when you have several.
    var account: (name: String, color: String)? = nil
    /// The mouse is over it: show the whole command and the details line.
    let expanded: Bool
    /// Branch, lines changed, tests, pull request, server, cost: shown on hover.
    var details: [Detail] = []
    let answer: (NotchModel.Answer) -> Void
    /// "Review plan": go to the conversation.
    var review: () -> Void = {}
    /// What this row's Clawd says he's doing ("Sautéing…"), matching his animation.
    @State private var word = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ClawdView(mode: session.clawdMode, color: color, onWord: { said in
                    withAnimation(.easeInOut(duration: 0.25)) { word = said }
                }, step: session.activity, reaction: Prefs.celebrations ? session.notice : nil)
                .frame(width: 40, height: 26)
                .overlay(alignment: .bottomTrailing) {
                    if session.work.helpers > 0 { HelperBadge(count: session.work.helpers) }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        if let model = session.model { ModelBadge(name: model) }
                        if let account { AccountChip(name: account.name, color: account.color) }
                    }
                    HStack(spacing: 6) {
                        Text(session.notice?.word ?? session.summary ?? label)
                            .foregroundStyle(session.notice?.color ?? tint)
                            .contentTransition(.opacity)
                            .fixedSize()
                        // What just happened ("91 passed"), or what Claude is doing right now.
                        if let note = session.notice?.detail ?? (session.state == .working ? session.activity : nil) {
                            Text(note)
                                .foregroundStyle(.white.opacity(0.6))
                                .layoutPriority(-1)   // the part that gets cut short when space runs out
                                .transition(.opacity)
                                .id(note)
                        }
                        Text(timeText)
                            .foregroundStyle(NotchView.dim)
                            .fixedSize()
                            .contentTransition(.numericText())
                            .animation(.snappy, value: timeText)
                        Outcome(tests: session.work.tests, pr: session.pr)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 8)

                if session.state == .waiting, session.plan {
                    Button("Review plan", action: review)
                        .buttonStyle(Pill(fill: NotchView.clay, text: .black))
                } else if session.canAnswer {
                    Button("Deny") { answer(.deny) }
                        .buttonStyle(Pill(fill: Color(white: 0.2), text: .white))
                    if session.always != nil {
                        Button("Always") { answer(.always) }
                            .buttonStyle(Pill(fill: Color(white: 0.2), text: .white))
                    }
                    Button("Allow") { answer(.allow) }
                        .buttonStyle(Pill(fill: NotchView.clay, text: .black))
                } else if let context = session.context {
                    ContextMeter(used: context)
                }
            }
            .frame(height: NotchModel.rowHeight)
            .overlay(alignment: .bottom) {
                if let todos = session.work.todos { TodoLine(todos: todos).padding(.leading, 50) }
            }

            if expanded, session.hoverLines > 0 || !details.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if session.hoverLines > 0, let detail = session.detail {
                        Text(detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(6)
                        if session.canAnswer, let always = session.always {
                            Text("Always allows \(always)")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchView.dim)
                                .lineLimit(1)
                        }
                    }
                    if !details.isEmpty { DetailsLine(details: details) }
                }
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 50)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle().fill(Color(white: 0.12)).frame(height: 1)
        }
        .help((session.title == nil ? "" : "In \(session.folder). ") + (session.state == .done ? "Click to open and clear" : "Click to open"))
    }

    private var label: String {
        switch session.state {
        case .ready: "Ready"
        case .working: word.hasSuffix("…") ? word : "Working"
        case .waiting: "Needs you"
        case .done: "Done"
        }
    }

    private var tint: Color {
        switch session.state {
        case .ready: NotchView.dim
        case .working: NotchView.clay
        case .waiting: NotchView.amber
        case .done: NotchView.green
        }
    }

    /// "now", "4m", "2h", "3d"
    /// Working: how long the job has been going. Otherwise: how long since it changed.
    private var timeText: String {
        if session.state == .working, let since = session.workingSince { return Self.elapsed(since, now: now) }
        return Self.ago(session.changed, now: now)
    }

    /// "42s", "12m", "1h 05m"
    static func elapsed(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h " + String(format: "%02dm", seconds / 60 % 60)
    }

    static func ago(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 60 * 24 { return "\(minutes / 60)h" }
        return "\(minutes / (60 * 24))d"
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
            Item(name, symbol: "arrow.triangle.branch")
        case .lines(let text):
            Self.colored(text)
        case .tests(let tests):
            Item(tests.text, symbol: tests.ok ? "checkmark" : "xmark")
                .foregroundStyle(tests.ok ? NotchView.green : NotchView.red)
        case .pullRequest(let pr):
            Button { NSWorkspace.shared.open(pr.url) } label: { Item(pr.text, symbol: "arrow.triangle.pull") }
                .buttonStyle(.plain)
                .foregroundStyle(Outcome.color(pr))
        case .server(let url):
            Button { NSWorkspace.shared.open(url) } label: { Item(detail.text, symbol: "arrow.up.right.square") }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.54, green: 0.71, blue: 0.97))
        case .todo(let text):
            Item(text, symbol: "checklist")
        case .cost:
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
