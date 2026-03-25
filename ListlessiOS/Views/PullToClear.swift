import SwiftUI

/// Pull distance at which the indicator signals readiness and completed item clearing triggers.
let pullClearThreshold: CGFloat = 50

struct PullToClearIndicator: View {
    let pullOffset: CGFloat

    private var progress: CGFloat { min(1, pullOffset / pullClearThreshold) }
    private var isReady: Bool { pullOffset >= pullClearThreshold }
    private let textSlideDistance: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Image(systemName: "checkmark")
                    .offset(y: isReady ? 0 : textSlideDistance)
                Image(systemName: "tray")
                    .offset(y: isReady ? -textSlideDistance : 0)
            }
            .frame(width: 26, height: textSlideDistance, alignment: .leading)
            .clipped()
            .foregroundStyle(.secondary)
            .font(.system(size: 17))
            .fontWeight(.semibold)
            .animation(.easeInOut(duration: 0.15), value: isReady)
            ZStack(alignment: .leading) {
                Text("Release to clear")
                    .offset(y: isReady ? 0 : textSlideDistance)
                Text("Clear completed")
                    .offset(y: isReady ? -textSlideDistance : 0)
            }
            .foregroundStyle(.secondary)
            .font(ItemRowMetrics.hintSUI)
            .frame(height: textSlideDistance, alignment: .topLeading)
            .clipped()
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
