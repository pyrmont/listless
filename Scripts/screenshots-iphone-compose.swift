#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

guard CommandLine.arguments.count >= 4 else {
    fputs("Usage: compose-screenshot.swift <input.png> <output.png> <text>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let text = CommandLine.arguments[3]

// Output dimensions (6.9" App Store)
let canvasWidth: CGFloat = 1320
let canvasHeight: CGFloat = 2868

// Background: rgb(30, 16, 40)
let bgColor = CGColor(red: 30.0 / 255.0, green: 16.0 / 255.0, blue: 40.0 / 255.0, alpha: 1.0)

// Load framed device image
guard let dataProvider = CGDataProvider(filename: inputPath),
    let deviceImage = CGImage(
        pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent)
else {
    fputs("Failed to load image: \(inputPath)\n", stderr)
    exit(1)
}

let deviceWidth = CGFloat(deviceImage.width)
let deviceHeight = CGFloat(deviceImage.height)

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

// Fill background
context.setFillColor(bgColor)
context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

// Scale device image to fit width with padding, leaving space for text
let bottomPadding: CGFloat = 60
let sidePadding: CGFloat = 60
let topReserved: CGFloat = 300
let maxDeviceWidth = canvasWidth - sidePadding * 2
let maxDeviceHeight = canvasHeight - bottomPadding - topReserved
let scale = min(maxDeviceWidth / deviceWidth, maxDeviceHeight / deviceHeight, 1.0)
let scaledWidth = deviceWidth * scale
let scaledHeight = deviceHeight * scale
let deviceX = (canvasWidth - scaledWidth) / 2
let deviceY = bottomPadding  // CG origin is bottom-left

context.draw(
    deviceImage, in: CGRect(x: deviceX, y: deviceY, width: scaledWidth, height: scaledHeight))

// Draw text centered above device
let fontSize: CGFloat = 72
let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
let attrString = NSAttributedString(string: text, attributes: attributes)
let ctLine = CTLineCreateWithAttributedString(attrString)
let textBounds = CTLineGetBoundsWithOptions(ctLine, .useOpticalBounds)

let textAreaTop = canvasHeight
let textAreaBottom = deviceY + scaledHeight
let textX = (canvasWidth - textBounds.width) / 2 - textBounds.origin.x
let textY = (textAreaTop + textAreaBottom) / 2 - textBounds.height / 2 - textBounds.origin.y

context.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(ctLine, context)

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
