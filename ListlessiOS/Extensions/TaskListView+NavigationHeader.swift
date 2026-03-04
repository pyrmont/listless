import SwiftUI

extension TaskListView {
    var navigationHeader: some View {
        HStack {
            Text(headingText)
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            Button {
                showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTaskID = nil
            focusedField = .scrollView
        }
    }
}
