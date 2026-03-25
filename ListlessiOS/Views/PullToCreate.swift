import SwiftUI

struct PullToCreateIndicator: View {
    let pullOffset: CGFloat
    let threshold: CGFloat
    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }

    static let indicatorHeight: CGFloat = 50

    private var isReady: Bool { pullOffset >= threshold }
    private let textSlideDistance: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: ItemRowMetrics.contentSpacing) {
            Image(systemName: "circle")
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.secondary)
                .font(.system(size: 17))
            ZStack(alignment: .leading) {
                Text("Release to add")
                    .offset(y: isReady ? 0 : -textSlideDistance)
                Text("New item")
                    .offset(y: isReady ? textSlideDistance : 0)
            }
            .foregroundStyle(.secondary)
            .font(ItemRowMetrics.bodySUI)
            .frame(height: textSlideDistance, alignment: .topLeading)
            .clipped()
            .animation(.easeInOut(duration: 0.18), value: isReady)
            Spacer()
        }
        .padding(.vertical, ItemRowMetrics.contentVerticalPadding)
        .padding(.trailing, ItemRowMetrics.contentHorizontalPadding)
        .padding(.leading, ItemRowMetrics.activeLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color.itemCard)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: ItemRowMetrics.trailingCornerRadius,
                topTrailingRadius: ItemRowMetrics.trailingCornerRadius
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(itemColor(forIndex: 0, total: 1, theme: colorTheme))
                .frame(width: ItemRowMetrics.accentBarWidth)
        }
        .frame(height: Self.indicatorHeight, alignment: .top)
        .allowsHitTesting(false)
    }
}
