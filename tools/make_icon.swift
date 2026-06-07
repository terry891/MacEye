import AppKit

// Renders the EyeBreak app icon at a given pixel size and returns PNG data.
// Theme: a friendly eye on the same indigo->teal gradient as the break overlay.
func render(_ S: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: S, height: S)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    let prev = NSGraphicsContext.current
    NSGraphicsContext.current = ctx
    let c = ctx.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // Rounded-rect "squircle" with macOS-style margin.
    let margin = S * 0.085
    let side = S - 2 * margin
    let rrect = CGRect(x: margin, y: margin, width: side, height: side)
    let radius = side * 0.2237
    let path = CGPath(roundedRect: rrect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow behind the squircle.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.03,
                color: NSColor.black.withAlphaComponent(0.28).cgColor)
    c.addPath(path); c.setFillColor(NSColor.white.cgColor); c.fillPath()
    c.restoreGState()

    // Gradient background (indigo top-left -> teal bottom-right) + top glow.
    c.saveGState()
    c.addPath(path); c.clip()
    let indigo = NSColor(srgbRed: 0.42, green: 0.36, blue: 0.92, alpha: 1).cgColor
    let teal = NSColor(srgbRed: 0.18, green: 0.71, blue: 0.74, alpha: 1).cgColor
    let grad = CGGradient(colorsSpace: cs, colors: [indigo, teal] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(grad, start: CGPoint(x: rrect.minX, y: rrect.maxY),
                         end: CGPoint(x: rrect.maxX, y: rrect.minY), options: [])
    let glow = CGGradient(colorsSpace: cs, colors: [
        NSColor.white.withAlphaComponent(0.30).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor,
    ] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(glow,
        startCenter: CGPoint(x: rrect.midX, y: rrect.maxY - side * 0.12), startRadius: 0,
        endCenter: CGPoint(x: rrect.midX, y: rrect.maxY - side * 0.12), endRadius: side * 0.62,
        options: [])
    c.restoreGState()

    // Eye geometry (nudged slightly below center to balance the sparkles above).
    let cx = S / 2, cy = S * 0.46
    let eyeW = S * 0.52, eyeH = S * 0.30

    // Almond (lens) eye outline.
    let almond = CGMutablePath()
    almond.move(to: CGPoint(x: cx - eyeW / 2, y: cy))
    almond.addCurve(to: CGPoint(x: cx + eyeW / 2, y: cy),
        control1: CGPoint(x: cx - eyeW * 0.25, y: cy + eyeH),
        control2: CGPoint(x: cx + eyeW * 0.25, y: cy + eyeH))
    almond.addCurve(to: CGPoint(x: cx - eyeW / 2, y: cy),
        control1: CGPoint(x: cx + eyeW * 0.25, y: cy - eyeH),
        control2: CGPoint(x: cx - eyeW * 0.25, y: cy - eyeH))
    almond.closeSubpath()

    // White of the eye.
    c.saveGState()
    c.addPath(almond); c.setFillColor(NSColor.white.cgColor); c.fillPath()
    c.restoreGState()

    // Iris + pupil + highlights, clipped to the almond (lids cut the iris naturally).
    c.saveGState()
    c.addPath(almond); c.clip()
    let irisR = S * 0.155
    c.saveGState()
    c.addEllipse(in: CGRect(x: cx - irisR, y: cy - irisR, width: 2 * irisR, height: 2 * irisR))
    c.clip()
    let irisGrad = CGGradient(colorsSpace: cs, colors: [
        NSColor(srgbRed: 0.27, green: 0.82, blue: 0.80, alpha: 1).cgColor,
        NSColor(srgbRed: 0.30, green: 0.32, blue: 0.86, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(irisGrad, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                         endCenter: CGPoint(x: cx, y: cy), endRadius: irisR, options: [])
    c.restoreGState()
    // Pupil.
    let pupR = irisR * 0.5
    c.setFillColor(NSColor(srgbRed: 0.10, green: 0.10, blue: 0.18, alpha: 1).cgColor)
    c.fillEllipse(in: CGRect(x: cx - pupR, y: cy - pupR, width: 2 * pupR, height: 2 * pupR))
    // Highlights.
    let hlR = irisR * 0.24
    c.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
    c.fillEllipse(in: CGRect(x: cx - irisR * 0.42, y: cy + irisR * 0.30, width: 2 * hlR, height: 2 * hlR))
    let hl2 = irisR * 0.11
    c.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    c.fillEllipse(in: CGRect(x: cx + irisR * 0.22, y: cy - irisR * 0.34, width: 2 * hl2, height: 2 * hl2))
    c.restoreGState()

    // Crisp almond outline.
    c.saveGState()
    c.addPath(almond)
    c.setStrokeColor(NSColor(srgbRed: 0.20, green: 0.22, blue: 0.45, alpha: 0.55).cgColor)
    c.setLineWidth(S * 0.012)
    c.strokePath()
    c.restoreGState()

    // Cute 4-point sparkles, upper-right.
    func sparkle(at p: CGPoint, r: CGFloat) {
        let k = r * 0.30
        let sp = CGMutablePath()
        sp.move(to: CGPoint(x: p.x, y: p.y + r))
        sp.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: CGPoint(x: p.x + k, y: p.y + k))
        sp.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: CGPoint(x: p.x + k, y: p.y - k))
        sp.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: CGPoint(x: p.x - k, y: p.y - k))
        sp.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x - k, y: p.y + k))
        sp.closeSubpath()
        c.addPath(sp); c.setFillColor(NSColor.white.cgColor); c.fillPath()
    }
    sparkle(at: CGPoint(x: cx + eyeW * 0.40, y: cy + eyeH * 1.35), r: S * 0.050)
    sparkle(at: CGPoint(x: cx + eyeW * 0.58, y: cy + eyeH * 0.75), r: S * 0.024)

    NSGraphicsContext.current = prev
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let items: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in items {
    let data = render(px)
    try! data.write(to: URL(fileURLWithPath: outDir + "/" + name))
}
print("wrote \(items.count) icon PNGs to \(outDir)")
