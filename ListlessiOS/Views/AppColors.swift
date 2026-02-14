import SwiftUI
import UIKit

extension Color {
    /// Warm gray canvas shown behind task cards and beneath completed-task text.
    static let outerBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.165, blue: 0.153, alpha: 1)  // #2C2A27
            : UIColor(red: 0.922, green: 0.906, blue: 0.886, alpha: 1)  // #EBE7E2
    })

    /// Stark card background: white in light mode, black in dark mode.
    static let taskCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })
}
