#!/usr/bin/swift
// Renders the Lumio app icon into Lumio/Resources/Assets.xcassets/AppIcon.appiconset.
// Run: Scripts/generate-icon.swift

import AppKit

let master = 1024
let image = NSImage(size: NSSize(width: master, height: master))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// macOS icon grid: 824pt rounded square centered on a 1024pt canvas.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()

// Deep night-sky gradient.
let bg = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rgba(38, 40, 74), rgba(16, 16, 30), rgba(7, 7, 14)] as CFArray,
    locations: [0, 0.55, 1]
)!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: plate.maxY), end: CGPoint(x: 512, y: plate.minY), options: [])

// Aurora glow radiating from behind the island.
let glowCenter = CGPoint(x: 512, y: 700)
let glow = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rgba(120, 110, 255, 0.85), rgba(70, 130, 255, 0.35), rgba(70, 130, 255, 0)] as CFArray,
    locations: [0, 0.45, 1]
)!
ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: 460, options: [])

// Secondary warm accent low-right for depth.
let warm = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rgba(255, 120, 190, 0.25), rgba(255, 120, 190, 0)] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(warm, startCenter: CGPoint(x: 720, y: 260), startRadius: 0, endCenter: CGPoint(x: 720, y: 260), endRadius: 420, options: [])

// The island: black pill near the top, lit by a thin gradient rim.
let pill = CGRect(x: 512 - 230, y: 700 - 80, width: 460, height: 160)
let pillPath = CGPath(roundedRect: pill, cornerWidth: 80, cornerHeight: 80, transform: nil)

ctx.setShadow(offset: .zero, blur: 90, color: rgba(110, 120, 255, 0.9))
ctx.addPath(pillPath)
ctx.setFillColor(rgba(5, 5, 10))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

ctx.addPath(CGPath(roundedRect: pill.insetBy(dx: 3, dy: 3), cornerWidth: 77, cornerHeight: 77, transform: nil))
ctx.setStrokeColor(rgba(160, 160, 255, 0.55))
ctx.setLineWidth(6)
ctx.strokePath()

// Sparkle accents echoing the idle-state UI.
func sparkle(_ center: CGPoint, _ radius: CGFloat, _ alpha: CGFloat) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(rgba(235, 235, 255, alpha))
    ctx.fillPath()
}
sparkle(CGPoint(x: 300, y: 430), 64, 0.95)
sparkle(CGPoint(x: 660, y: 330), 40, 0.75)
sparkle(CGPoint(x: 750, y: 480), 26, 0.5)

// Subtle top sheen on the plate.
let sheen = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [rgba(255, 255, 255, 0.14), rgba(255, 255, 255, 0)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: plate.maxY), end: CGPoint(x: 512, y: plate.maxY - 240), options: [])

ctx.restoreGState()

// Hairline border so the plate reads on white backgrounds.
ctx.addPath(platePath)
ctx.setStrokeColor(rgba(255, 255, 255, 0.08))
ctx.setLineWidth(2)
ctx.strokePath()

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let masterRep = NSBitmapImageRep(data: tiff) else {
    fatalError("failed to rasterize")
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let outDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Lumio/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func write(_ pixels: Int, _ name: String) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    masterRep.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

var entries: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try write(size * scale, name)
        entries.append("""
            {
              "filename" : "\(name)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(size)x\(size)"
            }
        """)
    }
}

let contents = """
{
  "images" : [
\(entries.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try contents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Wrote icon set to \(outDir.path)")
