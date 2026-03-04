import SwiftUI
import UIKit

extension Color {
    /// Canvas behind task cards: warm gray in light mode, black in dark mode.
    static let outerBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .black
            : UIColor(red: 0.922, green: 0.906, blue: 0.886, alpha: 1)  // #EBE7E2
    })

    /// Card surface: white in light mode, elevated dark gray in dark mode.
    static let taskCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.secondarySystemBackground : .white
    })

    /// Selected background for completed rows.
    static let completedSelected = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(red: 0.88, green: 0.86, blue: 0.83, alpha: 1)
    })

    /// Drop shadow for selected active cards in light mode.
    static let selectionShadowLight = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .clear
            : UIColor(white: 0.0, alpha: 0.25)
    })

    /// Glow for selected active cards in dark mode.
    static let selectionShadowDark = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 0.2)
            : .clear
    })
}
