import CoreGraphics
import SwiftUI
import UIKit

enum TaskRowMetrics {
    /// Base task-title font size (18pt), scaled by Dynamic Type.
    static let bodyUIK: UIFont = UIFontMetrics(forTextStyle: .body)
        .scaledFont(for: .systemFont(ofSize: 18))
    /// SwiftUI equivalent for use in pure SwiftUI views (e.g. PullToCreate).
    static let bodySUI: Font = .system(size: 18, weight: .regular)

    /// Hint font (17pt), scaled by Dynamic Type.
    static let hintUIK: UIFont = UIFontMetrics(forTextStyle: .body)
        .scaledFont(for: .systemFont(ofSize: 17))
    /// SwiftUI equivalent for use in pure SwiftUI views.
    static let hintSUI: Font = .system(size: 17, weight: .regular)

    static let accentBarWidth: CGFloat = 8
    static let trailingCornerRadius: CGFloat = 14
    static let contentSpacing: CGFloat = 12
    static let contentVerticalPadding: CGFloat = 14
    static let contentHorizontalPadding: CGFloat = 16
    static let activeLeadingPadding: CGFloat = 24
    static let completedLeadingPadding: CGFloat = 24
}
