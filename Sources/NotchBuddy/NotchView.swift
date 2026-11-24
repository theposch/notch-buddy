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
        let wing = model.wingWidth

        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                .fill(.black)
                .frame(width: size.width, height: size.height)
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
                .transition(.opacity)
            }

            HStack(spacing: 0) {
                // Clawd in the left wing. On the MacBook he sits against the camera;
                // on other screens, at the outer edge.
                ClawdView(mode: model.welcome ? "waiting" : model.clawdMode, color: model.clawdColor) { word in
                    withAnimation(.spring(duration: 0.32, bounce: 0.18)) { model.clawdWord = word }
                }
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: wing, height: g.barHeight, alignment: g.hasNotch ? .trailing : .leading)

                Spacer(minLength: g.cameraWidth)

                HStack(spacing: 6) {
                    if model.showsSpinner { Spinner().frame(width: 12, height: 12) }
                    Text(model.rightText ?? "")
                        .font(Font(NotchModel.wingFont))
                        .foregroundStyle(rightColor)
                        .lineLimit(1)
                        .fixedSize()
                        .id(model.rightText)   // fade between words instead of morphing
                        .transition(.opacity)
                }
                .frame(width: wing, height: g.barHeight)
            }
            .frame(width: model.closedSize.width)
            .opacity(open ? 0 : 1)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var rightColor: Color {
        if model.rightIsUsage, let left = model.usageLeft { return Self.usageColor(left, normal: Self.clay) }
        return Self.clay
    }

    // MARK: Open

    private var panel: some View {
        VStack(spacing: 0) {
            header
            rows
        }
        .padding(.horizontal, 16)
    }

    /// Usage left on the left; settings and Quit on the right.
    private var header: some View {
        HStack(spacing: 14) {
            if let left = model.usageLeft, let resets = model.usage?.resets {
                Text("\(left)% left")
                    .foregroundStyle(Self.usageColor(left, normal: .white))
                Text("resets \(resets.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(Self.dim)
            }
            Spacer()
            HeaderButton(symbol: "gearshape", help: "Settings", action: actions.settings)
            HeaderButton(symbol: "power", help: "Quit Notch Buddy", action: actions.quit)
        }
        .font(.system(size: 12, weight: .medium))
        .frame(height: NotchModel.headerHeight)
    }

    @ViewBuilder private var rows: some View {
        if model.sessions.isEmpty {
            Text("No sessions yet")
                .font(.system(size: 13))
                .foregroundStyle(Self.dim)
                .frame(maxHeight: .infinity)
        } else {
            // Redraw now and then so "2m ago" keeps counting.
            TimelineView(.periodic(from: .now, by: 30)) { time in
                VStack(spacing: 0) {
                    ForEach(model.rows.prefix(NotchModel.maxRows)) { session in
                        SessionRow(session: session, color: model.color(of: session), now: time.date) { allow in
                            withAnimation { model.answer(session, allow: allow) }
                        }
                        .onTapGesture { withAnimation { model.open(session) } }
                    }
                }
            }
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

/// A small turning arc, for the "Sessions" option while something is working.
struct Spinner: View {
    @State private var turning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(NotchView.clay, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: turning)
            .onAppear { turning = true }
    }
}

/// Clawd, project name, status and how long ago it changed.
/// When Claude is asking for permission: what it wants to do, with Allow and Deny.
struct SessionRow: View {
    let session: Session
    let color: String
    let now: Date
    let answer: (_ allow: Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ClawdView(mode: session.clawdMode, color: color)
                .frame(width: 40, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.folder)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(session.summary ?? label)
                        .foregroundStyle(tint)
                    if session.summary == nil {
                        Text(Self.ago(session.changed, now: now))
                            .foregroundStyle(NotchView.dim)
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: 8)

            if session.canAnswer {
                Button("Deny") { answer(false) }
                    .buttonStyle(Pill(fill: Color(white: 0.2), text: .white))
                Button("Allow") { answer(true) }
                    .buttonStyle(Pill(fill: NotchView.clay, text: .black))
            } else if session.summary != nil {
                Text(Self.ago(session.changed, now: now))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchView.dim)
            }
        }
        .frame(height: NotchModel.rowHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle().fill(Color(white: 0.12)).frame(height: 1)
        }
        .help(session.state == .done ? "Click to open and clear" : "Click to open")
    }

    private var label: String {
        switch session.state {
        case .ready: "Ready"
        case .working: "Working"
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
    static func ago(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 60 * 24 { return "\(minutes / 60)h" }
        return "\(minutes / (60 * 24))d"
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
