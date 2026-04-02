#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: screenshots-mac-desktop.swift <window.png> <output.png> [wallpaper]\n", stderr)
    exit(1)
}

let windowPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let wallpaperPath =
    CommandLine.arguments.count >= 4
    ? CommandLine.arguments[3]
    : "sequoia-light.jpg"

// MacBook Air 13" 4th Gen native resolution
let canvasWidth: CGFloat = 2560
let canvasHeight: CGFloat = 1664

// Load wallpaper (supports HEIC, JPEG, PNG via ImageIO)
guard let wpData = try? Data(contentsOf: URL(fileURLWithPath: wallpaperPath)),
    let wpSource = CGImageSourceCreateWithData(wpData as CFData, nil),
    let wallpaper = CGImageSourceCreateImageAtIndex(wpSource, 0, nil)
else {
    fputs("Failed to load wallpaper: \(wallpaperPath)\n", stderr)
    exit(1)
}

// Load window screenshot
guard let winProvider = CGDataProvider(filename: windowPath),
    let windowImage = CGImage(
        pngDataProviderSource: winProvider, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent)
else {
    fputs("Failed to load window image: \(windowPath)\n", stderr)
    exit(1)
}

// Create canvas
guard
    let context = CGContext(
        data: nil,
        width: Int(canvasWidth),
        height: Int(canvasHeight),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

// Draw wallpaper: scale to fit width, align to top, crop from bottom
let wpWidth = CGFloat(wallpaper.width)
let wpHeight = CGFloat(wallpaper.height)
let wpScale = canvasWidth / wpWidth
let scaledWpHeight = wpHeight * wpScale
// CG origin is bottom-left; align top edge of wallpaper to top of canvas
let wpY = canvasHeight - scaledWpHeight
context.draw(
    wallpaper, in: CGRect(x: 0, y: wpY, width: canvasWidth, height: scaledWpHeight))

// Draw menu bar: translucent strip at the top (@2x: 60px ≈ 30pt)
let menuBarHeight: CGFloat = 60
let menuBarY = canvasHeight - menuBarHeight
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
context.fill(CGRect(x: 0, y: menuBarY, width: canvasWidth, height: menuBarHeight))

// Helper to draw a menu bar SF Symbol via CTFont
func drawMenuSymbol(_ name: String, at x: CGFloat, size: CGFloat) -> CGFloat {
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
        return x
    }
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
    let configured = image.withSymbolConfiguration(config) ?? image
    // Tint the symbol
    let tinted = NSImage(size: configured.size, flipped: false) { rect in
        menuTextColor.set()
        rect.fill(using: .sourceOver)
        configured.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        return true
    }
    let imgWidth = tinted.size.width
    let imgHeight = tinted.size.height
    let imgY = menuBarY + (menuBarHeight - imgHeight) / 2
    guard let cgImage = tinted.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return x
    }
    context.draw(cgImage, in: CGRect(x: x, y: imgY, width: imgWidth, height: imgHeight))
    return x + imgWidth
}

// Helper to draw menu bar text
let menuTextColor = NSColor(white: 0.0, alpha: 0.85)
func drawMenuText(_ text: String, at x: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular)
    -> CGFloat
{
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: menuTextColor,
    ]
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    let y = menuBarY + (menuBarHeight - bounds.height) / 2 - bounds.origin.y
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
    return x + bounds.width
}

// Left side: Apple logo, app name, menus
let appleFont = NSFont(name: "SF Pro Display", size: 42) ?? NSFont.systemFont(ofSize: 42)
let appleAttrs: [NSAttributedString.Key: Any] = [
    .font: appleFont,
    .foregroundColor: menuTextColor,
]
let appleString = NSAttributedString(string: "\u{F8FF}", attributes: appleAttrs)
let appleLine = CTLineCreateWithAttributedString(appleString)
let appleBounds = CTLineGetBoundsWithOptions(appleLine, .useOpticalBounds)
let appleX: CGFloat = 32
let appleTextY = menuBarY + (menuBarHeight - appleBounds.height) / 2 - appleBounds.origin.y
context.textPosition = CGPoint(x: appleX, y: appleTextY)
CTLineDraw(appleLine, context)

var curX = appleX + appleBounds.width + 40
curX = drawMenuText("Listless", at: curX, size: 28, weight: .bold) + 36
curX = drawMenuText("File", at: curX, size: 28) + 36
curX = drawMenuText("Edit", at: curX, size: 28) + 36
curX = drawMenuText("View", at: curX, size: 28) + 36
curX = drawMenuText("Window", at: curX, size: 28) + 36
_ = drawMenuText("Help", at: curX, size: 28)

// Right side: icons, date and time
var rightX = canvasWidth - 260
_ = drawMenuText("Wed 9 Apr  9:41 AM", at: rightX, size: 28)
rightX -= 20
_ = drawMenuSymbol("switch.2", at: rightX - 44, size: 32)
_ = drawMenuSymbol("magnifyingglass", at: rightX - 100, size: 28)

// Scale and draw window screenshot offset slightly right of centre
let winWidth = CGFloat(windowImage.width)
let winHeight = CGFloat(windowImage.height)
let winScale = (canvasWidth * 0.4) / winWidth
let scaledWinWidth = winWidth * winScale
let scaledWinHeight = winHeight * winScale
let winX = (canvasWidth - scaledWinWidth) / 2 + 400
let availableHeight = canvasHeight - menuBarHeight
let winY = (availableHeight - scaledWinHeight) / 2 + 150
context.draw(
    windowImage,
    in: CGRect(x: winX, y: winY, width: scaledWinWidth, height: scaledWinHeight))

// Save
guard let resultImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: outputPath) as CFURL,
        "public.png" as CFString,
        1,
        nil
    )
else {
    fputs("Failed to create output\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, resultImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Failed to write output\n", stderr)
    exit(1)
}
