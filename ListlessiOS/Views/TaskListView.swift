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
    @State var pullToCreate = PullToCreateState()
    @State var pullUpOffset: CGFloat = 0
    @State var isDragging: Bool = false
    @State var rowFrames: [UUID: CGRect] = [:]

    var vStackSpacing: CGFloat { 12 }
    var pullCreateThreshold: CGFloat { 70 }
    var isCompletelyEmpty: Bool { activeTasks.isEmpty && completedTasks.isEmpty }

    init(store: TaskStore, syncMonitor: CloudKitSyncMonitor) {
        self.store = store
        self.syncMonitor = syncMonitor
    }

    func didStartDrag() {
        isDragging = true
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    var body: some View {
        taskScrollView
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

    private var taskScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: vStackSpacing) {
                navigationHeader
                pullToCreateIndicatorRow
                ForEach(Array(displayActiveTasks.enumerated()), id: \.element.id) { index, task in
                    let taskID = task.id
                    TaskRowView(
                        task: task,
                        taskID: taskID,
                        index: index,
                        totalTasks: displayActiveTasks.count,
                        isSelected: selectedTaskID == taskID,
                        isDragging: $isDragging,
                        focusedField: $focusedField,
                        onToggle: { toggleCompletion($0) },
                        onTitleChange: { updateTitle($0, $1) },
                        onDelete: { deleteTask($0) },
                        onSelect: { selectTask($0) },
                        onStartEdit: { startEditing($0) },
                        onEndEdit: { endEditing($0, shouldCreateNewTask: $1) }
                    )
                    .scaleEffect(draggedTaskID == taskID ? 1.05 : 1.0)
                    .shadow(
                        color: draggedTaskID == taskID ? .black.opacity(0.3) : .clear,
                        radius: 12, y: 4
                    )
                    .zIndex(draggedTaskID == taskID ? 1 : 0)
                    .taskDragGesture(
                        isActive: !task.isCompleted,
                        taskID: taskID,
                        onDragStart: { startDrag(taskID: taskID) },
                        onDragChanged: { point in handleIOSDragChanged(taskID: taskID, point: point) },
                        onDragEnded: { commitIOSDrag() }
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        rowFrames[taskID] = frame
                    }
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
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .offset(y: -pullToCreate.pullOffset)
        }
        .scrollDisabled(draggedTaskID != nil)
        .scrollBounceBehavior(.always)
        .background {
            Color.outerBackground.ignoresSafeArea()
        }
        .overlay {
            if isCompletelyEmpty {
                Text("Pull down to create")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            pullToClearIndicatorRow
        }
        .pullCreationGesture(
            pullToCreate: $pullToCreate,
            pullUpOffset: $pullUpOffset,
            activeTaskIDs: activeTasks.map(\.id),
            hasCompletedTasks: !completedTasks.isEmpty,
            pullCreateThreshold: pullCreateThreshold,
            pullClearThreshold: pullClearThreshold,
            onCreateTaskAtTop: { createNewTaskAtTop() },
            onClearCompleted: { clearCompletedTasks() }
        )
    }
}
