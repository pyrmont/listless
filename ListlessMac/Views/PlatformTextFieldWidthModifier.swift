import SwiftUI

private struct TextFieldWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MacTextFieldWidthModifier: ViewModifier {
    let text: String
    let placeholder: String

    @State private var measuredWidth: CGFloat = 60

    func body(content: Content) -> some View {
        content
            .frame(width: max(44, measuredWidth + 12), alignment: .leading)
            .background(widthMeasurer)
            .onPreferenceChange(TextFieldWidthPreferenceKey.self) { width in
                if width > 0, width != measuredWidth {
                    measuredWidth = width
                }
            }
    }

    private var widthMeasurer: some View {
        Text(displayText)
            .font(.body)
            .lineLimit(1)
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: TextFieldWidthPreferenceKey.self, value: proxy.size.width)
                }
            )
            .hidden()
    }

    private var displayText: String {
        text.isEmpty ? placeholder : text
    }
}

extension View {
    func platformTextFieldWidth(text: String, placeholder: String) -> some View {
        modifier(MacTextFieldWidthModifier(text: text, placeholder: placeholder))
    }
}
