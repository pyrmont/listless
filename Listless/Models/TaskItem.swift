import CoreData
import Foundation

@objc(TaskItem)
public class TaskItem: NSManagedObject, Identifiable {
    private enum Keys {
        private static func key<Value>(_ keyPath: KeyPath<TaskItem, Value>) -> String {
            NSExpression(forKeyPath: keyPath).keyPath
        }

        static let id = key(\TaskItem.id as KeyPath<TaskItem, UUID>)
        static let title = key(\TaskItem.title)
        static let isCompleted = key(\TaskItem.isCompleted)
        static let createdAt = key(\TaskItem.createdAt)
        static let updatedAt = key(\TaskItem.updatedAt)
        static let sortOrder = key(\TaskItem.sortOrder)
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var sortOrder: Int64

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskItem> {
        return NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: Keys.id)
        setPrimitiveValue(Date(), forKey: Keys.createdAt)
        setPrimitiveValue(Date(), forKey: Keys.updatedAt)
        setPrimitiveValue(false, forKey: Keys.isCompleted)
        setPrimitiveValue("", forKey: Keys.title)
        setPrimitiveValue(0, forKey: Keys.sortOrder)
    }

    public override func willSave() {
        super.willSave()
        if !isDeleted && changedValues().keys.contains(where: { $0 != Keys.updatedAt }) {
            setPrimitiveValue(Date(), forKey: Keys.updatedAt)
        }
    }
}
