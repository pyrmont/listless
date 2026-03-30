import Foundation

@MainActor
enum TutorialSeeder {
    static func seed(store: ItemStore) {
        let titles = [
            "Swipe left to complete",
            "Swipe right to delete",
            "Long press and drag to reorder",
            "Tap the text to edit",
            "Pull down to create",
            "Or tap below to create",
            "Pull up to clear",
        ]

        for (index, title) in titles.enumerated() {
            do {
                _ = try store.createItem(
                    title: title,
                    sortOrder: Int64(index) * 1000
                )
            } catch {
                continue
            }
        }

        do {
            try store.save()
        } catch {}
    }
}
