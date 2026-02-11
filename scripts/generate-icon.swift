#!/usr/bin/env swift
// Generates a YouTube-style app icon (red rounded rect + white play triangle)
// as an .icns file with all required sizes.

import Cocoa

/// Draw the icon at a given size: red rounded rectangle with white play triangle
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let iconRect = bounds.insetBy(dx: inset, dy: inset)

    // Red rounded rectangle background
    let cornerRadius = size * 0.18
    let bgPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 0.94, green: 0.13, blue: 0.13, alpha: 1.0).setFill()  // YouTube red (#F00)

    // Subtle shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.shadowBlurRadius = size * 0.04
    shadow.set()

    bgPath.fill()

    // Remove shadow for the play triangle
    NSShadow().set()

    // White play triangle — centered, slightly right of center (optical balance)
    let triHeight = size * 0.36
    let triWidth = triHeight * 0.9
    let centerX = size / 2 + size * 0.02  // nudge right for optical center
    let centerY = size / 2

    let triPath = NSBezierPath()
    triPath.move(to: NSPoint(x: centerX - triWidth / 2, y: centerY + triHeight / 2))
    triPath.line(to: NSPoint(x: centerX - triWidth / 2, y: centerY - triHeight / 2))
    triPath.line(to: NSPoint(x: centerX + triWidth / 2, y: centerY))
    triPath.close()

    NSColor.white.setFill()
    triPath.fill()

    image.unlockFocus()
    return image
}

/// Convert NSImage to PNG data at a specific pixel size
func pngData(image: NSImage, pixelSize: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
               from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

// Icon sizes required for .icns (name: pixel size)
let iconSizes = [16, 32, 64, 128, 256, 512, 1024]

// Generate the icon at high resolution
let icon = drawIcon(size: 1024)

// Create an iconset directory
let projectDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconsetPath = "\(projectDir)/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Write PNGs at all required sizes (1x and 2x)
let sizeSpecs: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for spec in sizeSpecs {
    let data = pngData(image: icon, pixelSize: spec.pixels)
    let path = "\(iconsetPath)/\(spec.name).png"
    try data.write(to: URL(fileURLWithPath: path))
}

print("Iconset created at \(iconsetPath)")
print("Converting to .icns...")

// Convert iconset to icns using iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "\(projectDir)/AppIcon.icns"]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    // Clean up iconset directory
    try? fm.removeItem(atPath: iconsetPath)
    print("AppIcon.icns created successfully")
} else {
    print("Error: iconutil failed with status \(process.terminationStatus)")
}
