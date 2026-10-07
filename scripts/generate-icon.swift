#!/usr/bin/env swift
// Generates the app icon (Support/AppIcon.icns) and the README logo
// (docs/images/app-icon.png) from code, so the artwork is reviewable and reproducible.
// Drawn by hand: SF Symbols may not be used in app icons.
//
// Usage: swift scripts/generate-icon.swift
import AppKit

let indigo = NSColor(srgbRed: 0x4F / 255, green: 0x46 / 255, blue: 0xE5 / 255, alpha: 1)
let indigoDeep = NSColor(srgbRed: 0x3F / 255, green: 0x37 / 255, blue: 0xC9 / 255, alpha: 1)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let unit = size / 1024

  // macOS icon grid: 824pt body, centred, continuous-ish corners.
  let body = NSRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
  let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * unit, yRadius: 185 * unit)
  NSGradient(starting: indigo, ending: indigoDeep)!.draw(in: squircle, angle: -90)

  // Shield.
  let shield = NSBezierPath()
  let cx = 512 * unit
  shield.move(to: NSPoint(x: cx, y: 770 * unit))
  shield.curve(
    to: NSPoint(x: 300 * unit, y: 690 * unit),
    controlPoint1: NSPoint(x: 430 * unit, y: 735 * unit),
    controlPoint2: NSPoint(x: 360 * unit, y: 715 * unit))
  shield.line(to: NSPoint(x: 300 * unit, y: 520 * unit))
  shield.curve(
    to: NSPoint(x: cx, y: 250 * unit),
    controlPoint1: NSPoint(x: 300 * unit, y: 390 * unit),
    controlPoint2: NSPoint(x: 400 * unit, y: 300 * unit))
  shield.curve(
    to: NSPoint(x: 724 * unit, y: 520 * unit),
    controlPoint1: NSPoint(x: 624 * unit, y: 300 * unit),
    controlPoint2: NSPoint(x: 724 * unit, y: 390 * unit))
  shield.line(to: NSPoint(x: 724 * unit, y: 690 * unit))
  shield.curve(
    to: NSPoint(x: cx, y: 770 * unit),
    controlPoint1: NSPoint(x: 664 * unit, y: 715 * unit),
    controlPoint2: NSPoint(x: 594 * unit, y: 735 * unit))
  shield.close()
  NSColor.white.setFill()
  shield.fill()

  // Check mark, cut out in the body colour.
  let check = NSBezierPath()
  check.move(to: NSPoint(x: 420 * unit, y: 515 * unit))
  check.line(to: NSPoint(x: 490 * unit, y: 445 * unit))
  check.line(to: NSPoint(x: 615 * unit, y: 590 * unit))
  check.lineWidth = 58 * unit
  check.lineCapStyle = .round
  check.lineJoinStyle = .round
  indigo.setStroke()
  check.stroke()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(filePath: path))
}

let fileManager = FileManager.default
let iconset = fileManager.temporaryDirectory.appending(path: "AppIcon.iconset").path
try? fileManager.removeItem(atPath: iconset)
try! fileManager.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
  write(drawIcon(size: CGFloat(points)), to: "\(iconset)/icon_\(points)x\(points).png")
  write(drawIcon(size: CGFloat(points * 2)), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}

let iconutil = Process()
iconutil.executableURL = URL(filePath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "Support/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()

write(drawIcon(size: 256), to: "docs/images/app-icon.png")
print("Wrote Support/AppIcon.icns and docs/images/app-icon.png")
