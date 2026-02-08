import AppKit
import SwiftUI

struct TextHoverModifier: ViewModifier {
    let isCompleted: Bool

    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if !isCompleted {
                if isHovering {
                    NSCursor.iBeam.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}
