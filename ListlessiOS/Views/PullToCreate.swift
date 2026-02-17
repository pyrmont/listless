import SwiftUI

/// Pull distance at which the indicator signals readiness and task creation triggers.
let pullCreateThreshold: CGFloat = 70

struct PullToCreateIndicator: View {
    let pullOffset: CGFloat

    private var progress: CGFloat { min(1, pullOffset / pullCreateThreshold) }
    private var isReady: Bool { pullOffset >= pullCreateThreshold }

    // Matches the "top" gradient stop used for the first active task row
    private let accentColor = Color(hue: 0.98, saturation: 0.85, brightness: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
            HStack(spacing: 6) {
                Image(systemName: isReady ? "checkmark" : "plus")
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .animation(.easeInOut(duration: 0.15), value: isReady)
                Text(isReady ? "Release to add" : "New task")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .animation(.easeInOut(duration: 0.15), value: isReady)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .background(Color.taskCard)
        }
        .frame(height: 56)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 14, topTrailingRadius: 14
            )
        )
        .padding(.trailing, 16)
        // Reveal from the top downward as the user pulls
        .frame(height: min(pullOffset, 56), alignment: .top)
        .clipped()
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}
