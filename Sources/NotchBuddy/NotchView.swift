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
                ClawdView(mode: model.clawdMode) { word in
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
            VStack(spacing: 0) {
                ForEach(model.sessions.prefix(NotchModel.maxRows)) { session in
                    SessionRow(session: session)
                        .onTapGesture { withAnimation { model.dismiss(session) } }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            Text(session.folder)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(height: NotchModel.rowHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle().fill(Color(white: 0.12)).frame(height: 1)
        }
        .help(session.state == .done ? "Click to clear" : "")
    }

    private var label: String {
        switch session.state {
        case .ready: "Ready"
        case .working: "Working"
        case .waiting: "Needs you"
        case .done: "Done"
        }
    }

    private var color: Color {
        switch session.state {
        case .ready: NotchView.dim
        case .working: NotchView.clay
        case .waiting: NotchView.amber
        case .done: NotchView.green
        }
    }
}
