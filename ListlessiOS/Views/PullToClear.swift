import SwiftUI

/// Pull distance at which the indicator signals readiness and completed task clearing triggers.
let pullClearThreshold: CGFloat = 70

struct PullToClearIndicator: View {
    let pullOffset: CGFloat

    private var progress: CGFloat { min(1, pullOffset / pullClearThreshold) }
    private var isReady: Bool { pullOffset >= pullClearThreshold }

    // Matches the "bottom" gradient stop used for the last active task row
    private let accentColor = Color(hue: 0.72, saturation: 0.65, brightness: 0.85)

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
            HStack(spacing: 6) {
                Image(systemName: isReady ? "checkmark" : "trash")
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .animation(.easeInOut(duration: 0.15), value: isReady)
                Text(isReady ? "Release to clear" : "Clear completed")
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
        // Reveal from the bottom upward as the user pulls
        .frame(height: min(pullOffset, 56), alignment: .bottom)
        .clipped()
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}
