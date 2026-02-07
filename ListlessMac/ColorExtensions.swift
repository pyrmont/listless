import AppKit
import SwiftUI

typealias PlatformColor = NSColor

extension NSColor {
    var hsba: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        // Convert to RGB color space first for consistency
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return (0, 0, 0, 0)
        }
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return (Double(hue), Double(saturation), Double(brightness), Double(alpha))
    }
}
