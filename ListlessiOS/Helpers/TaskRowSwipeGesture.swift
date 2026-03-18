import SwiftUI

extension View {
    func taskSwipeVisuals(
        swipeOffset: CGFloat,
        swipeDirection: TaskRowSwipeGesture.SwipeDirection,
        isTriggered: Bool,
        completeColor: Color = .green
    ) -> some View {
        self.modifier(
            TaskRowSwipeGesture(
                swipeOffset: swipeOffset,
                swipeDirection: swipeDirection,
                isTriggered: isTriggered,
                completeColor: completeColor
            ))
    }
}

/// Visual-only modifier that draws the swipe background (complete/delete) and
/// offsets the row content horizontally. The actual gesture is handled at the
/// ScrollView level to avoid iOS 26's child-gesture-blocks-ancestor issue.
struct TaskRowSwipeGesture: ViewModifier {
    let swipeOffset: CGFloat
    let swipeDirection: SwipeDirection
    let isTriggered: Bool
    let completeColor: Color

    enum SwipeDirection: Equatable {
        case left
        case right
        case none
    }

    static let completeThreshold: CGFloat = 40
    static let deleteThreshold: CGFloat = 80
    static let horizontalBufferPt: CGFloat = 10
    static let offsetDamping: CGFloat = 0.9

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            // Background stays in place
            swipeBackground
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            // Only the content moves
            content
                .offset(x: swipeOffset)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if swipeDirection == .right {
            // Complete action — accent color background
            completeColor.opacity(backgroundOpacity(offset: swipeOffset))
        } else if swipeDirection == .left {
            // Delete action (red background, trash icon)
            Color.red.opacity(backgroundOpacity(offset: swipeOffset))
                .overlay {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isTriggered ? .black : .white)
                            .padding(.trailing, 20)
                    }
                }
        }
    }

    private func backgroundOpacity(offset: CGFloat) -> CGFloat {
        let threshold = offset >= 0 ? Self.completeThreshold : Self.deleteThreshold
        return min(abs(offset) / threshold, 1.0)
    }
}
