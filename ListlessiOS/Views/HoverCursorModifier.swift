import SwiftUI

struct TextHoverModifier: ViewModifier {
    let isCompleted: Bool

    func body(content: Content) -> some View {
        // No-op on iOS - cursors don't apply
        content
    }
}
