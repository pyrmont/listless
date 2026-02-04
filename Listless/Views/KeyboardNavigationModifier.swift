import SwiftUI

extension View {
    func keyboardNavigation(
        onUpArrow: @escaping () -> KeyPress.Result,
        onDownArrow: @escaping () -> KeyPress.Result,
        onSpace: @escaping () -> KeyPress.Result,
        onReturn: @escaping () -> KeyPress.Result,
        onEscape: @escaping () -> KeyPress.Result
    ) -> some View {
        self
            .onKeyPress(.upArrow) {
                onUpArrow()
            }
            .onKeyPress(.downArrow) {
                onDownArrow()
            }
            .onKeyPress(.space) {
                onSpace()
            }
            .onKeyPress(.return) {
                onReturn()
            }
            .onKeyPress(.escape) {
                onEscape()
            }
    }
}
