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
}
