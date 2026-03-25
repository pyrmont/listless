import SwiftUI

extension ItemListView {
    @ToolbarContentBuilder
    var platformToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Spacer()
        }

        ToolbarItemGroup(placement: .automatic) {
            HStack {
                if syncMonitor.hasDiagnosticsIssue {
                    Button {
                        NSApp.sendAction(
                            #selector(AppDelegate.handleShowSyncDiagnostics),
                            to: nil, from: nil
                        )
                    } label: {
                        Label("Sync Issues", systemImage: "exclamationmark.icloud")
                    }
                    .help("View sync diagnostics")

                    Divider()
                }

                Button {
                    createNewItem()
                } label: {
                    Label("New Item", systemImage: "plus")
                }
                .help("Create a new item")

                Button {
                    _ = deleteSelectedItem()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!canDeleteSelectionFromList)
                .help("Delete selected item")

                Divider()

                Button {
                    clearCompletedItems()
                } label: {
                    Label("Clear Completed", systemImage: "tray")
                }
                .disabled(completedItems.isEmpty)
                .help("Clear all completed items")
            }
        }
    }
}
