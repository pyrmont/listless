import SwiftUI

extension ItemListView {
    @ViewBuilder
    private var overflowMenu: some View {
        if #available(iOS 26.0, *) {
            Menu {
                overflowMenuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .circle)
        } else {
            Menu {
                overflowMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var overflowMenuItems: some View {
        Button {
            showRenameAlert()
        } label: {
            Label("Rename List", systemImage: "pencil")
        }
        Button(role: .destructive) {
            iState.isShowingDeleteAllAlert = true
        } label: {
            Label("Delete All", systemImage: "trash")
        }
        .disabled(items.isEmpty)
        Divider()
        Button {
            showSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }

    var navigationHeader: some View {
        HStack {
            Text(headingText)
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            if syncMonitor.hasDiagnosticsIssue {
                Button {
                    showSyncDiagnostics()
                } label: {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            overflowMenu
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            fState.selectedItemID = nil
            focusedField = nil
        }
    }
}
