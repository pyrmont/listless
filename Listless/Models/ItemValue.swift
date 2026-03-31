import Foundation

struct ItemValue: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int64
    var completedOrder: Int64

    init(_ entity: ItemEntity) {
        self.id = entity.id
        self.title = entity.title
        self.isCompleted = entity.isCompleted
        self.sortOrder = entity.sortOrder
        self.completedOrder = entity.completedOrder
    }
}
