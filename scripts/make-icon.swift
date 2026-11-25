// Draws Notch Buddy's app icon: Clawd under a notch, on a dark rounded square.
// Clawd uses the same pixel grid as Resources/clawd.html.
// Usage: swift scripts/make-icon.swift <out.png>   (scripts/make-icon.sh turns it into AppIcon.icns)
import AppKit

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
do {
    let c = NSGraphicsContext.current!.cgContext
    c.translateBy(x: 0, y: 1024); c.scaleBy(x: 1, y: -1)   // draw from the top down
    func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: a)
    }

    // The rounded square, with macOS's standard margin.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    c.saveGState()
    c.addPath(shape); c.clip()
    let fill = CGGradient(colorsSpace: nil, colors: [color(0x2B2A28), color(0x121211)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(fill, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])

    // The notch hanging from the top edge.
    let notch = CGRect(x: 512 - 150, y: tile.minY - 50, width: 300, height: 160)
    c.addPath(CGPath(roundedRect: notch, cornerWidth: 46, cornerHeight: 46, transform: nil))
    c.setFillColor(color(0x000000)); c.fillPath()

    // Clawd: 16 x 10 pixels (12 x 8 body, arms out, four legs), as in his logo.
    let u: CGFloat = 32
    let ox = 512 - 8 * u, oy: CGFloat = 600 - 5 * u
    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: CGColor) {
        c.setFillColor(col); c.fill(CGRect(x: ox + x * u, y: oy + y * u, width: w * u, height: h * u))
    }
    let clay = color(0xD97757), eye = color(0x141413)
    for lx in [3, 5, 10, 12] as [CGFloat] { px(lx, 8, 1, 2, clay) }   // legs
    px(2, 0, 12, 8, clay)                                             // body
    px(0, 4, 2, 2, clay)                                              // left arm, out
    px(14, 4, 2, 2, clay)                                             // right arm, out
    px(4, 2, 1, 2, eye); px(11, 2, 1, 2, eye)                         // eyes
    c.restoreGState()

    // A faint edge so the tile reads on dark backgrounds.
    c.addPath(shape); c.setStrokeColor(color(0xFFFFFF, 0.08)); c.setLineWidth(3); c.strokePath()
}
NSGraphicsContext.current?.flushGraphics()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
