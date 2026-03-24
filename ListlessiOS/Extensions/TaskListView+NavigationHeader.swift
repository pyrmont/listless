import SwiftUI

extension TaskListView {
    @ViewBuilder
    private var settingsButton: some View {
        Button {
            showSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

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
            if #available(iOS 26.0, *) {
                settingsButton.buttonStyle(.glass)
            } else {
                settingsButton.buttonStyle(.plain)
            }
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
