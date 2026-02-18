import SwiftUI

struct TaskListView: View {
    enum FocusField: Hashable {
        case task(UUID)
        case scrollView
    }

    enum DragState: Equatable {
        case idle
        case dragging(id: UUID, order: [UUID])
    }

    @Environment(\.undoManager) var undoManager
    @Environment(\.managedObjectContext) var managedObjectContext

    let store: TaskStore
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true),
        ],
        animation: .default
    )
    var tasks: FetchedResults<TaskItem>
    @FocusState var focusedField: FocusField?
    @State var selectedTaskID: UUID?
    @State private var refreshID = UUID()
    @State var dragState: DragState = .idle
    @State var pendingFocus: FocusField?
    @State var pullOffset: CGFloat = 0

    var vStackSpacing: CGFloat { 0 }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func didStartDrag() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        index: index,
                        totalTasks: displayActiveTasks.count,
                        isSelected: selectedTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) }
                    )
                    .taskDragGesture(
                        isActive: !task.isCompleted,
                        taskID: task.id,
                        onDragStart: { startDrag(taskID: task.id) }
                    )
                    .overlay {
                        if draggedTaskID != nil && draggedTaskID != task.id {
                            VStack(spacing: 0) {
                                // Top 1/6 - insert BEFORE
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
                                            if isTargeted {
                                                updateVisualOrder(insertBefore: task.id)
                                            }
                                        })

                                // Middle 2/3 - insert based on direction
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(4)
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
                                            if isTargeted {
                                                updateVisualOrderSmart(relativeTo: task.id)
                                            }
                                        })

                                // Bottom 1/6 - insert AFTER
                                Color.clear
                                    .frame(maxHeight: .infinity)
                                    .layoutPriority(1)
                                    .dropDestination(
                                        for: String.self, action: { _, _ in false },
                                        isTargeted: { isTargeted in
                                            if isTargeted {
                                                updateVisualOrder(insertAfter: task.id)
                                            }
                                        })
                            }
                        }
                    }
                }

                // Drop zone at the end
                if !activeTasks.isEmpty && draggedTaskID != nil {
                    Color.clear
                        .frame(height: 44)
                        .dropDestination(
                            for: String.self, action: { _, _ in false },
                            isTargeted: { isTargeted in
                                if isTargeted {
                                    updateVisualOrder(insertAtEnd: true)
                                }
                            })
                }

                ForEach(completedTasks) { task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        isSelected: selectedTaskID == taskID,
                        focusedField: $focusedField,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .offset(y: -pullOffset)
            .dropDestination(for: String.self) { items, location in
                handleDrop(items: items)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleBackgroundTap()
        }
        .focusable()
        .focused($focusedField, equals: .scrollView)
        .focusEffectDisabled()
        .accessibilityIdentifier("task-list-scrollview")
        .keyboardNavigation([
            ShortcutKey(key: .upArrow): navigateUp,
            ShortcutKey(key: .downArrow): navigateDown,
            ShortcutKey(key: .space): toggleSelectedTask,
            ShortcutKey(key: .return): focusSelectedTask,
            ShortcutKey(key: .delete): deleteSelectedTask,
        ])
        .onAppear {
            if focusedField == nil {
                focusedField = .scrollView
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            handleFocusChange(from: oldValue, to: newValue)

            if newValue == nil {
                if let pending = pendingFocus {
                    print("🟣 onChange resolving pendingFocus: \(pending)")
                    focusedField = pending
                    pendingFocus = nil
                } else {
                    print("🟣 onChange repairing nil focus to .scrollView")
                    focusedField = .scrollView
                }
            }
        }
        .onChange(of: undoManager, initial: true) { _, newValue in
            managedObjectContext.undoManager = newValue
        }
        .toolbar {
            platformToolbar
        }
        .overlay(alignment: .top) {
            syncErrorBanner
        }
        .alert(
            item: Binding(
                get: { syncMonitor.actionableAlert },
                set: { if $0 == nil { syncMonitor.clearActionableAlert() } }
            )
        ) { alert in
            switch alert.action {
            case .openSettings:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Settings")) { openSystemSettings() },
                    secondaryButton: .cancel(Text("OK")) {
                        syncMonitor.clearActionableAlert()
                    }
                )

            case .none:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        syncMonitor.clearActionableAlert()
                    }
                )
            }
        }
    }
}
