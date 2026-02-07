import UIKit
import SwiftUI

typealias PlatformColor = UIColor

extension UIColor {
    var hsba: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return (Double(hue), Double(saturation), Double(brightness), Double(alpha))
    }
}
