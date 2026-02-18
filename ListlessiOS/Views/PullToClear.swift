import SwiftUI

/// Pull distance at which the indicator signals readiness and completed task clearing triggers.
let pullClearThreshold: CGFloat = 70

struct PullToClearIndicator: View {
    let pullOffset: CGFloat

    private var progress: CGFloat { min(1, pullOffset / pullClearThreshold) }
    private var isReady: Bool { pullOffset >= pullClearThreshold }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isReady ? "checkmark" : "trash")
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
                .animation(.easeInOut(duration: 0.15), value: isReady)
            Text(isReady ? "Release to clear" : "Clear completed")
                .foregroundStyle(.secondary)
                .font(.body)
                .animation(.easeInOut(duration: 0.15), value: isReady)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        // Reveal from the bottom upward as the user pulls
        .frame(height: min(pullOffset, 56), alignment: .bottom)
        .clipped()
        .opacity(Double(progress))
        .allowsHitTesting(false)
    }
}
