#!/usr/bin/env swift
// Generates Phosphene.icns — a dark gradient circle with a play-triangle cutout.
// Usage: swift generate-icon.swift <output-path>

import AppKit
import Foundation

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Phosphene.icns"

let sizes: [(name: String, px: Int)] = [
    ("ic07", 128),   // 128x128
    ("ic08", 256),   // 256x256
    ("ic09", 512),   // 512x512
    ("ic10", 1024),  // 512x512@2x
    ("ic11", 32),    // 16x16@2x
    ("ic12", 64),    // 32x32@2x
    ("ic13", 256),   // 128x128@2x
    ("ic14", 512),   // 256x256@2x
]

func renderIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    )!

    // Background: transparent
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Rounded rect (macOS icon shape) with gradient
    let inset = s * 0.1
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = (s - inset * 2) * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Dark purple-to-deep-blue gradient
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.18, green: 0.02, blue: 0.38, alpha: 1.0),
        CGColor(red: 0.02, green: 0.08, blue: 0.28, alpha: 1.0),
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: s * 0.2, y: s * 0.9),
        end: CGPoint(x: s * 0.8, y: s * 0.1),
        options: []
    )

    // Subtle inner glow
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 0.25),
        CGColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 0.0),
    ] as CFArray, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: s * 0.35, y: s * 0.65),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
        endRadius: s * 0.45,
        options: []
    )

    ctx.restoreGState()

    // Play triangle — white, centered, slightly right-offset for optical balance
    let triH = s * 0.32
    let triW = triH * 0.9
    let cx = s * 0.52  // slight right offset
    let cy = s * 0.5

    let tri = CGMutablePath()
    tri.move(to: CGPoint(x: cx - triW * 0.4, y: cy + triH * 0.5))
    tri.addLine(to: CGPoint(x: cx - triW * 0.4, y: cy - triH * 0.5))
    tri.addLine(to: CGPoint(x: cx + triW * 0.6, y: cy))
    tri.closeSubpath()

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
    ctx.addPath(tri)
    ctx.fillPath()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

// Build ICNS manually
var icnsData = Data()

// Header: 'icns' + total length (placeholder)
icnsData.append(contentsOf: [0x69, 0x63, 0x6E, 0x73]) // 'icns'
icnsData.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // length placeholder

for (name, px) in sizes {
    let pngData = renderIcon(size: px)
    let typeBytes = Array(name.utf8)
    let entryLength = UInt32(8 + pngData.count)

    icnsData.append(contentsOf: typeBytes)
    icnsData.append(contentsOf: withUnsafeBytes(of: entryLength.bigEndian) { Array($0) })
    icnsData.append(pngData)
}

// Patch total length
let totalLength = UInt32(icnsData.count)
icnsData.replaceSubrange(4..<8, with: withUnsafeBytes(of: totalLength.bigEndian) { Array($0) })

let url = URL(fileURLWithPath: outputPath)
try! icnsData.write(to: url)
print("Generated \(outputPath) (\(icnsData.count) bytes)")
