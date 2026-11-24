import AppKit
import SwiftUI

/// The black notch: a small bar with Clawd in the left wing when closed,
/// a wider panel when open.
struct NotchView: View {
    let model: NotchModel

    private static let dim = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x95 / 255)

    var body: some View {
        let g = model.geometry
        let open = model.isOpen
        let size = open ? NotchGeometry.openSize : g.closedSize
        let radius = open ? NotchGeometry.openRadius : NotchGeometry.closedRadius

        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                .fill(.black)
                .frame(width: size.width, height: size.height)
                .contextMenu {
                    Button("Quit Notch Buddy") { NSApp.terminate(nil) }
                }

            if open {
                Text("No sessions yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Self.dim)
                    .frame(width: size.width, height: size.height - g.barHeight)
                    .padding(.top, g.barHeight)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Clawd in the left wing. On the MacBook he sits against the camera;
            // on other screens, at the outer edge.
            ClawdView()
                .frame(width: 48, height: 31)
                .padding(.horizontal, 4)
                .frame(width: NotchGeometry.wing, height: g.barHeight,
                       alignment: g.hasNotch ? .trailing : .leading)
                .frame(width: g.closedSize.width, alignment: .leading)
                .opacity(open ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
