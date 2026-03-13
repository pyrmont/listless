import CoreData
import SwiftUI

@MainActor
protocol TaskListViewProtocol {
    var tasks: FetchedResults<TaskItem> { get }
    var store: TaskStore { get }
    var syncMonitor: CloudKitSyncMonitor { get }
    var managedObjectContext: NSManagedObjectContext { get }
    var focusedField: FocusField? { get nonmutating set }
    var fState: FocusStateData { get nonmutating set }
    var dragState: DragState { get nonmutating set }
    var draftPlacement: DraftTaskPlacement? { get nonmutating set }
    var draftTitle: String { get nonmutating set }
    func didStartDrag()
    func clearDraftTaskUI(at placement: DraftTaskPlacement, hasTitle: Bool)
}
