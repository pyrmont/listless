import SwiftUI

/// Pull distance at which the indicator signals readiness and task creation triggers.
let pullCreateThreshold: CGFloat = 70

struct PullToCreateIndicator: View {
    let pullOffset: CGFloat

    private var progress: CGFloat { min(1, pullOffset / pullCreateThreshold) }
    private var isReady: Bool { pullOffset >= pullCreateThreshold }
    private let indicatorHeight: CGFloat = 48
    private let textSlideDistance: CGFloat = 22

    // Matches the "top" gradient stop used for the first active task row
    private let accentColor = Color(hue: 0.98, saturation: 0.85, brightness: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 17))
                    .fontWeight(.thin)
                ZStack(alignment: .leading) {
                    Text("Release to add")
                        .offset(y: isReady ? 0 : -textSlideDistance)
                    Text("New task")
                        .offset(y: isReady ? textSlideDistance : 0)
                }
                .foregroundStyle(.secondary)
                .font(.body)
                .frame(height: textSlideDistance, alignment: .topLeading)
                .clipped()
                .animation(.easeInOut(duration: 0.18), value: isReady)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.taskCard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 14, topTrailingRadius: 14
            )
        )
        // Reveal from the top downward as the user pulls
        .frame(height: min(pullOffset, indicatorHeight), alignment: .top)
        .clipped()
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}
