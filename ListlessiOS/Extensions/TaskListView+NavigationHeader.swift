import SwiftUI

extension TaskListView {
    var navigationHeader: some View {
        HStack {
            Text(headingText)
                .font(.largeTitle)
                .fontWeight(.bold)
                .onTapGesture(count: 4) {
                    showSyncDiagnostics()
                }
            Spacer()
            if syncMonitor.hasDiagnosticsIssue {
                Button {
                    showSyncDiagnostics()
                } label: {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
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
            fState.selectedTaskID = nil
            focusedField = nil
        }
    }
}
