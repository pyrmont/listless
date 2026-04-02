#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: add-dynamic-island.swift <image.png> [output.png]\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : inputPath

guard let dataProvider = CGDataProvider(filename: inputPath),
    let image = CGImage(
        pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent)
else {
    fputs("Failed to load image: \(inputPath)\n", stderr)
    exit(1)
}

let width = CGFloat(image.width)
let height = CGFloat(image.height)

// Dynamic Island dimensions as proportions of screen width
let pillWidth = width * 0.280
let pillHeight = width * 0.062
let pillY = width * 0.050
let pillX = (width - pillWidth) / 2
let cornerRadius = pillHeight / 2

guard
    let context = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    fputs("Failed to create graphics context\n", stderr)
    exit(1)
}

// Draw original image
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

// Draw Dynamic Island pill (CG origin is bottom-left, so flip Y)
let flippedY = height - pillY - pillHeight
let pillRect = CGRect(x: pillX, y: flippedY, width: pillWidth, height: pillHeight)
let pillPath = CGPath(
    roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.addPath(pillPath)
context.fillPath()

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
