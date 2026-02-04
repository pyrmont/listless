import SwiftUI

extension View {
    func keyboardNavigation(
        onUpArrow: @escaping () -> Void,
        onDownArrow: @escaping () -> Void
    ) -> some View {
        self
            .onKeyPress(.upArrow) {
                print("KeyboardNavigation: upArrow pressed")
                onUpArrow()
                return .handled
            }
            .onKeyPress(.downArrow) {
                print("KeyboardNavigation: downArrow pressed")
                onDownArrow()
                return .handled
            }
    }
}
