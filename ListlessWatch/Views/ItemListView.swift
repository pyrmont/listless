import CoreData
import SwiftUI

struct ItemListView: View {
    let store: ItemStore
    let syncMonitor: CloudKitSyncMonitor

    @AppStorage("headingText") private var headingText = "Items"

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\ItemEntity.sortOrder, order: .forward),
        ],
        animation: .default
    )
    private var items: FetchedResults<ItemEntity>

    var body: some View {
        let activeItems = items.filter { !$0.isCompleted }
        let completedItems = items.filter { $0.isCompleted }
            .sorted { $0.completedOrder > $1.completedOrder }

        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "checklist",
                        description: Text("Add items on your iPhone or Mac.")
                    )
                } else {
                    List {
                        ForEach(Array(activeItems.enumerated()), id: \.element.id) { index, item in
                            ItemRowView(
                                item: item,
                                index: index,
                                totalActive: activeItems.count,
                                onToggle: { toggleItem($0) }
                            )
                        }

                        if !completedItems.isEmpty {
                            Section("Completed") {
                                ForEach(completedItems) { item in
                                    ItemRowView(
                                        item: item,
                                        index: 0,
                                        totalActive: 0,
                                        onToggle: { toggleItem($0) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(headingText)
        }
    }

    private func toggleItem(_ item: ItemEntity) {
        do {
            if item.isCompleted {
                try store.uncomplete(itemID: item.id)
            } else {
                try store.complete(itemID: item.id)
            }
        } catch {
            // Sync monitor handles error reporting
        }
    }
}
