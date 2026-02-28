import SwiftUI

extension TaskListView {
    var navigationHeader: some View {
        Text("Tasks")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedTaskID = nil
                focusedField = .scrollView
            }
            .simultaneousGesture(
                TapGesture(count: 4).onEnded {
                    showSyncDiagnostics()
                }
            )
    }
}
