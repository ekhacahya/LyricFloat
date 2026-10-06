import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
func render(_ pixels: Int) throws -> Data {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -14)
    graphics.saveGraphicsState(); shadow.set()
    NSColor(calibratedRed: 0.07, green: 0.1, blue: 0.09, alpha: 1).setFill(); tile.fill()
    graphics.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.23, alpha: 1), ending: NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.085, alpha: 1))!.draw(in: tile, angle: -75)
    NSColor.white.withAlphaComponent(0.13).setStroke(); tile.lineWidth = 3; tile.stroke()
    // Floating lyric card; three lines echo the app's compact mode.
    let card = NSBezierPath(roundedRect: NSRect(x: 178, y: 240, width: 668, height: 520), xRadius: 94, yRadius: 94)
    NSColor.white.withAlphaComponent(0.06).setFill(); card.fill()
    NSColor.white.withAlphaComponent(0.14).setStroke(); card.lineWidth = 3; card.stroke()
    func bar(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ alpha: CGFloat) {
        NSColor(calibratedRed: 0.67, green: 0.94, blue: 0.78, alpha: alpha).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: height / 2, yRadius: height / 2).fill()
    }
    bar(294, 637, 312, 28, 0.30)
    bar(294, 527, 436, 40, 1)
    bar(294, 437, 350, 40, 1)
    bar(294, 337, 242, 28, 0.30)
    // A small play mark makes the music connection readable at Dock sizes.
    let play = NSBezierPath(); play.move(to: NSPoint(x: 225, y: 436)); play.line(to: NSPoint(x: 225, y: 566)); play.line(to: NSPoint(x: 274, y: 501)); play.close()
    NSColor(calibratedRed: 0.67, green: 0.94, blue: 0.78, alpha: 1).setFill(); play.fill()
    let image = context.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: destination.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: destination.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
