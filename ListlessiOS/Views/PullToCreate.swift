import SwiftUI

struct PullToCreateIndicator: View {
    let pullOffset: CGFloat
    let threshold: CGFloat

    private var progress: CGFloat { min(1, pullOffset / threshold) }
    private var isReady: Bool { pullOffset >= threshold }
    private let indicatorHeight: CGFloat = 48
    private let textSlideDistance: CGFloat = 22

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(taskColor(forIndex: 0, total: 1))
                .frame(width: TaskRowMetrics.accentBarWidth)
            HStack(alignment: .center, spacing: TaskRowMetrics.contentSpacing) {
                Image(systemName: "circle")
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
            .padding(.horizontal, TaskRowMetrics.contentHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.taskCard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: TaskRowMetrics.trailingCornerRadius,
                topTrailingRadius: TaskRowMetrics.trailingCornerRadius
            )
        )
        // Reveal from the top downward as the user pulls
        .frame(height: min(pullOffset, indicatorHeight), alignment: .top)
        .clipped()
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}
