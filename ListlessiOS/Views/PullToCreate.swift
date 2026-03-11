import SwiftUI

struct PullToCreateIndicator: View {
    let pullOffset: CGFloat
    let threshold: CGFloat

    static let indicatorHeight: CGFloat = 50

    private var revealedHeight: CGFloat { min(pullOffset, Self.indicatorHeight) }
    private var isReady: Bool { pullOffset >= threshold }
    private let textSlideDistance: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: TaskRowMetrics.contentSpacing) {
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
            .font(TaskRowMetrics.bodySUI)
            .frame(height: textSlideDistance, alignment: .topLeading)
            .clipped()
            .animation(.easeInOut(duration: 0.18), value: isReady)
            Spacer()
        }
        .padding(.vertical, TaskRowMetrics.contentVerticalPadding)
        .padding(.trailing, TaskRowMetrics.contentHorizontalPadding)
        .padding(.leading, TaskRowMetrics.activeLeadingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(Color.taskCard)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: TaskRowMetrics.trailingCornerRadius,
                topTrailingRadius: TaskRowMetrics.trailingCornerRadius
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(taskColor(forIndex: 0, total: 1))
                .frame(width: TaskRowMetrics.accentBarWidth)
        }
        .frame(height: Self.indicatorHeight, alignment: .top)
        .mask(alignment: .top) {
            Rectangle()
                .frame(height: revealedHeight)
        }
        .background(alignment: .top) {
            Color.taskCard
                .frame(
                    height: min(
                        TaskRowMetrics.trailingCornerRadius,
                        Self.indicatorHeight - revealedHeight
                    )
                )
                .offset(y: revealedHeight)
        }
        .allowsHitTesting(false)
    }
}
