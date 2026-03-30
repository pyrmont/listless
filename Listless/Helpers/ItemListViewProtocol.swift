import CoreData
import SwiftUI

@MainActor
protocol ItemListViewProtocol {
    var items: FetchedResults<ItemEntity> { get }
    var store: ItemStore { get }
    var syncMonitor: CloudKitSyncMonitor { get }
    var managedObjectContext: NSManagedObjectContext { get }
    var focusedField: FocusField? { get nonmutating set }
    var fState: FocusStateData { get nonmutating set }
    var dragState: DragState { get nonmutating set }
    var draftPlacement: DraftItemPlacement? { get nonmutating set }
    var draftTitle: String { get nonmutating set }
    func didStartDrag()
    func revealDraftItemUI(at placement: DraftItemPlacement, animated: Bool)
    func clearDraftItemUI(at placement: DraftItemPlacement, hasTitle: Bool)
}
