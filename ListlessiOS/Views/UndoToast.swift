import SwiftUI

struct UndoToastData: Equatable, Identifiable {
    let id: UUID
    let message: String
}

struct UndoToastView: View {
    let data: UndoToastData
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(data.message)
                .font(.body)
                .foregroundStyle(.white)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.2))
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
