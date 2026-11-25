import SwiftUI

/// The notch's outline, like the hardware: flat along the top of the screen, small curved
/// "shoulders" where it meets the menu bar, straight sides, and soft rounded corners at the
/// bottom that ease into the straight edges instead of meeting them at a sharp seam.
/// It's wider than the black body by one shoulder on each side.
struct NotchShape: Shape {
    var shoulder: CGFloat
    var corner: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulder, corner) }
        set { (shoulder, corner) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let s = min(shoulder, rect.width / 4, rect.height / 2)
        let left = rect.minX + s, right = rect.maxX - s, bottom = rect.maxY
        // The bottom corners reach a little further than a plain circle would, then ease in.
        let e = min(corner * 1.2, (right - left) / 2, rect.height - s)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: left, y: rect.minY + s), control: CGPoint(x: left, y: rect.minY))
        p.addLine(to: CGPoint(x: left, y: bottom - e))
        p.addCurve(to: CGPoint(x: left + e, y: bottom),
                   control1: CGPoint(x: left, y: bottom - e * 0.4), control2: CGPoint(x: left + e * 0.4, y: bottom))
        p.addLine(to: CGPoint(x: right - e, y: bottom))
        p.addCurve(to: CGPoint(x: right, y: bottom - e),
                   control1: CGPoint(x: right - e * 0.4, y: bottom), control2: CGPoint(x: right, y: bottom - e * 0.4))
        p.addLine(to: CGPoint(x: right, y: rect.minY + s))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Content arriving in the open notch: it starts a little small, see-through and soft,
/// and sharpens into place as the notch grows, the way the Dynamic Island does.
struct GrowIn: ViewModifier {
    var shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 6)
            .scaleEffect(shown ? 1 : 0.94, anchor: .top)
    }
}

extension AnyTransition {
    static var growIn: AnyTransition { .modifier(active: GrowIn(shown: false), identity: GrowIn(shown: true)) }
}

/// Rows arrive one after another, a few hundredths of a second apart.
struct Stagger: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .modifier(GrowIn(shown: shown))
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.15).delay(0.05 + Double(index) * 0.035)) { shown = true }
            }
    }
}
