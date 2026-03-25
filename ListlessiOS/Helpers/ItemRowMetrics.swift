import CoreGraphics
import SwiftUI
import UIKit

enum ItemRowMetrics {
    /// Base item-title font size (18pt), scaled by Dynamic Type.
    static let bodyUIK: UIFont = UIFontMetrics(forTextStyle: .body)
        .scaledFont(for: .systemFont(ofSize: 18))
    /// SwiftUI equivalent for use in pure SwiftUI views (e.g. PullToCreate).
    /// Uses Dynamic Type scaling to match bodyUIK (18pt base, scaled relative to .body).
    static let bodySUI: Font = Font(bodyUIK)

    /// Hint font (17pt), scaled by Dynamic Type.
    static let hintUIK: UIFont = UIFontMetrics(forTextStyle: .body)
        .scaledFont(for: .systemFont(ofSize: 17))
    /// SwiftUI equivalent for use in pure SwiftUI views.
    /// Uses Dynamic Type scaling to match hintUIK (17pt base, scaled relative to .body).
    static let hintSUI: Font = Font(hintUIK)

    static let accentBarWidth: CGFloat = 8
    static let trailingCornerRadius: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let contentVerticalPadding: CGFloat = 14
    static let contentHorizontalPadding: CGFloat = 16
    static let activeLeadingPadding: CGFloat = 24
    static let completedLeadingPadding: CGFloat = 24
}
