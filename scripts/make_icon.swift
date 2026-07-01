import AppKit

// Quix app icon üretici: gradient squircle + beyaz bolt.
// Çıktı: Resources/AppIcon.icns  (ve Resources/AppIcon-preview.png)

func render(pixels: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Squircle gövde (macOS ikon marjı ile)
    let margin = size * 0.092
    let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.42, green: 0.47, blue: 1.00, alpha: 1.0),
        NSColor(srgbRed: 0.28, green: 0.22, blue: 0.78, alpha: 1.0)
    ])!
    gradient.draw(in: rect, angle: -90)
    // yumuşak üst parlaklık (keskin kenar yok)
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.16),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    sheen.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Beyaz bolt glyph (SF Symbol)
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .bold)
    if let base = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let g = base.size
        // beyaza boya
        let white = NSImage(size: g)
        white.lockFocus()
        base.draw(at: .zero, from: CGRect(origin: .zero, size: g), operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        CGRect(origin: .zero, size: g).fill(using: .sourceAtop)
        white.unlockFocus()

        let target = min(rect.width, rect.height) * 0.52
        let scale = target / max(g.width, g.height)
        let gw = g.width * scale, gh = g.height * scale
        let gx = rect.midX - gw / 2, gy = rect.midY - gh / 2
        white.draw(in: CGRect(x: gx, y: gy, width: gw, height: gh),
                   from: CGRect(origin: .zero, size: g), operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try? data.write(to: URL(fileURLWithPath: path))
}

let root = FileManager.default.currentDirectoryPath
let iconset = "\(root)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// iconutil için gerekli boyutlar
let specs: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for spec in specs {
    writePNG(render(pixels: spec.px), to: "\(iconset)/\(spec.name).png")
}
writePNG(render(pixels: 512), to: "\(root)/Resources/AppIcon-preview.png")
print("iconset hazır: \(iconset)")
