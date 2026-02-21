#!/usr/bin/env swift

import Cocoa
import CoreGraphics

// Icon generator for GPLift
// Run with: swift GenerateAppIcon.swift

let size: CGFloat = 1024
let outputPath = "GPLift/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

// Create the image
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {
    print("Failed to create context")
    exit(1)
}

// Flip coordinate system
context.translateBy(x: 0, y: size)
context.scaleBy(x: 1, y: -1)

// Draw background with rounded corners
let cornerRadius: CGFloat = size * 0.22
let backgroundPath = CGPath(
    roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

// Gradient colors (orange)
let gradientColors: [CGFloat] = [
    1.0, 0.55, 0.15, 1.0,  // Start color (lighter orange)
    0.95, 0.35, 0.05, 1.0   // End color (darker orange)
]

guard let gradient = CGGradient(
    colorSpace: colorSpace,
    colorComponents: gradientColors,
    locations: [0, 1],
    count: 2
) else {
    print("Failed to create gradient")
    exit(1)
}

context.saveGState()
context.addPath(backgroundPath)
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)
context.restoreGState()

// Draw dumbbell icon (white)
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))

let centerX = size / 2
let centerY = size / 2

// Dumbbell dimensions
let plateWidth: CGFloat = size * 0.1
let plateHeight: CGFloat = size * 0.4
let innerPlateWidth: CGFloat = size * 0.055
let innerPlateHeight: CGFloat = size * 0.28
let barHeight: CGFloat = size * 0.08
let plateRadius: CGFloat = size * 0.028
let innerPlateRadius: CGFloat = size * 0.02
let barRadius: CGFloat = barHeight / 2

// Left outer plate
let leftOuterPlate = CGPath(
    roundedRect: CGRect(
        x: centerX - size * 0.31,
        y: centerY - plateHeight / 2,
        width: plateWidth,
        height: plateHeight
    ),
    cornerWidth: plateRadius,
    cornerHeight: plateRadius,
    transform: nil
)
context.addPath(leftOuterPlate)
context.fillPath()

// Left inner plate
let leftInnerPlate = CGPath(
    roundedRect: CGRect(
        x: centerX - size * 0.195,
        y: centerY - innerPlateHeight / 2,
        width: innerPlateWidth,
        height: innerPlateHeight
    ),
    cornerWidth: innerPlateRadius,
    cornerHeight: innerPlateRadius,
    transform: nil
)
context.addPath(leftInnerPlate)
context.fillPath()

// Center bar
let barWidth = size * 0.25
let bar = CGPath(
    roundedRect: CGRect(
        x: centerX - barWidth / 2,
        y: centerY - barHeight / 2,
        width: barWidth,
        height: barHeight
    ),
    cornerWidth: barRadius,
    cornerHeight: barRadius,
    transform: nil
)
context.addPath(bar)
context.fillPath()

// Right inner plate
let rightInnerPlate = CGPath(
    roundedRect: CGRect(
        x: centerX + size * 0.14,
        y: centerY - innerPlateHeight / 2,
        width: innerPlateWidth,
        height: innerPlateHeight
    ),
    cornerWidth: innerPlateRadius,
    cornerHeight: innerPlateRadius,
    transform: nil
)
context.addPath(rightInnerPlate)
context.fillPath()

// Right outer plate
let rightOuterPlate = CGPath(
    roundedRect: CGRect(
        x: centerX + size * 0.21,
        y: centerY - plateHeight / 2,
        width: plateWidth,
        height: plateHeight
    ),
    cornerWidth: plateRadius,
    cornerHeight: plateRadius,
    transform: nil
)
context.addPath(rightOuterPlate)
context.fillPath()

// Create image from context
guard let cgImage = context.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))

// Save as PNG
guard let tiffData = nsImage.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let fileURL = URL(fileURLWithPath: outputPath)
do {
    try pngData.write(to: fileURL)
    print("✅ App icon saved to: \(outputPath)")
} catch {
    print("❌ Failed to save icon: \(error)")
    exit(1)
}
