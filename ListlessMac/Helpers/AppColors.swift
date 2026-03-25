import SwiftUI

extension Color {
    /// Canvas behind item rows: warm gray in light mode, default window background in dark mode.
    static let outerBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .windowBackgroundColor
            : NSColor(red: 0.922, green: 0.906, blue: 0.886, alpha: 1)  // #EBE7E2
    })
}
