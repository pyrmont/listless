import Foundation
import CoreData

@objc(TaskItem)
public class TaskItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskItem> {
        return NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Date(), forKey: "updatedAt")
        setPrimitiveValue(false, forKey: "isCompleted")
        setPrimitiveValue("", forKey: "title")
    }

    public override func willSave() {
        super.willSave()
        if !isDeleted && changedValues().keys.contains(where: { $0 != "updatedAt" }) {
            setPrimitiveValue(Date(), forKey: "updatedAt")
        }
    }
}
