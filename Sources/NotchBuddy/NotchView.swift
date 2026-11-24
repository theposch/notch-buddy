import AppKit
import SwiftUI

/// The black notch: Clawd in the left wing and a count or word in the right one when closed,
/// one row per Claude Code session when open.
struct NotchView: View {
    let model: NotchModel
    let menu: NotchMenu

    static let clay = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    static let amber = Color(red: 0xE8 / 255, green: 0xC6 / 255, blue: 0x6A / 255)
    static let green = Color(red: 0x8F / 255, green: 0xBF / 255, blue: 0x6A / 255)
    static let dim = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x95 / 255)

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
                    Button("Install Claude hooks", action: menu.installHooks)
                    Button("Remove Claude hooks", action: menu.removeHooks)
                    Divider()
                    Button("Quit Notch Buddy") { NSApp.terminate(nil) }
                }

            if open {
                rows
                    .frame(width: size.width, height: size.height - g.barHeight, alignment: .top)
                    .padding(.top, g.barHeight)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                // Clawd in the left wing. On the MacBook he sits against the camera;
                // on other screens, at the outer edge.
                ClawdView(mode: model.clawdMode, color: model.clawdColor) { word in
                    withAnimation(.spring(duration: 0.32, bounce: 0.18)) { model.clawdWord = word }
                }
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: wing, height: g.barHeight, alignment: g.hasNotch ? .trailing : .leading)

                Spacer(minLength: g.cameraWidth)

                Text(model.rightText ?? "")
                    .font(Font(NotchModel.wingFont))
                    .foregroundStyle(Self.clay)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: wing, height: g.barHeight)
            }
            .frame(width: model.closedSize.width)
            .opacity(open ? 0 : 1)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
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
