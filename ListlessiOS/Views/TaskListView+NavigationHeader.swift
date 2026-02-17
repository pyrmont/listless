import SwiftUI

extension TaskListView {
    var navigationHeader: some View {
        Text("Tasks")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .onTapGesture {
                selectedTaskID = nil
                focusedField = .scrollView
            }
    }
}
