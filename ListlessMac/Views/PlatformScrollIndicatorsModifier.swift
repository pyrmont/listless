import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PlatformScrollIndicatorsModifier: ViewModifier {
    let verticalPadding: CGFloat
    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let effectiveContentHeight = max(0, contentHeight - (verticalPadding * 2))
            content
                .background(
                    GeometryReader { contentProxy in
                        Color.clear.preference(
                            key: ContentHeightKey.self, value: contentProxy.size.height)
                    }
                )
                .scrollIndicators(effectiveContentHeight > proxy.size.height ? .visible : .hidden)
                .onPreferenceChange(ContentHeightKey.self) { height in
                    if height != contentHeight {
                        contentHeight = height
                    }
                }
        }
    }
}

extension View {
    func platformScrollIndicators(verticalPadding: CGFloat = 0) -> some View {
        modifier(PlatformScrollIndicatorsModifier(verticalPadding: verticalPadding))
    }
}
