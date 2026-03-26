import CoreData
import SwiftUI

struct ItemListView: View {
    let store: ItemStore
    let syncMonitor: CloudKitSyncMonitor

    @AppStorage("listName") private var listName = "Items"
    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }

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
                                colorTheme: colorTheme,
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
                                        colorTheme: colorTheme,
                                        onToggle: { toggleItem($0) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(listName)
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
