import SwiftUI

struct ItemRowView: View {
    let item: ItemValue
    let itemID: UUID
    let index: Int
    let totalItems: Int
    let isSelected: Bool
    @Binding var isDragging: Bool
    @Binding var isSwiping: Bool
    let onToggle: (UUID) -> Void
    let onTitleChange: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onSelect: (UUID) -> Void
    let isLastActiveItem: Bool
    let onStartEdit: (UUID) -> Void
    let onEndEdit: (UUID, _ shouldCreateNewItem: Bool) -> Void
    @FocusState.Binding var focusedField: FocusField?

    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }
    @State private var swipeOffset: CGFloat = 0
    @State private var swipeDirection: ItemRowSwipeGesture.SwipeDirection = .none
    @State private var isSwipeTriggered: Bool = false
    @State private var editingTitle: String = ""
    @State private var isCurrentlyEditing: Bool = false
    @State private var tapPoint: CGPoint? = nil
    @State private var cachedAccentColor: Color = .clear

    init(
        item: ItemValue,
        itemID: UUID,
        index: Int = 0,
        totalItems: Int = 1,
        isSelected: Bool,
        isDragging: Binding<Bool> = .constant(false),
        isSwiping: Binding<Bool> = .constant(false),
        isLastActiveItem: Bool = false,
        focusedField: FocusState<FocusField?>.Binding,
        onToggle: @escaping (UUID) -> Void,
        onTitleChange: @escaping (UUID, String) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onSelect: @escaping (UUID) -> Void,
        onStartEdit: @escaping (UUID) -> Void = { _ in },
        onEndEdit: @escaping (UUID, _ shouldCreateNewItem: Bool) -> Void = { _, _ in }
    ) {
        self.item = item
        self.itemID = itemID
        self.index = index
        self.totalItems = totalItems
        self.isSelected = isSelected
        _isDragging = isDragging
        _isSwiping = isSwiping
        self.isLastActiveItem = isLastActiveItem
        self.onToggle = onToggle
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        self.onStartEdit = onStartEdit
        self.onEndEdit = onEndEdit
        _focusedField = focusedField
    }

    var body: some View {
        HStack(alignment: .center, spacing: ItemRowMetrics.contentSpacing) {
            Button {
                onToggle(itemID)
            } label: {
                // When a right-swipe is past the threshold, preview the toggled state
                let previewCompleted = isSwipeTriggered && swipeDirection == .right
                    ? !item.isCompleted
                    : item.isCompleted
                Image(systemName: previewCompleted ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.identity)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Color.secondary)
                    .font(.system(size: 17))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("item-checkbox")
            .accessibilityValue(item.isCompleted ? "checkmark.circle.fill" : "circle")

            if !item.isCompleted && (isSelected || isEditing) {
                TappableTextField(
                    text: $editingTitle,
                    isCompleted: item.isCompleted,
                    isDragging: isDragging,
                    onEditingChanged: { editing, shouldCreateNewItem in
                        DispatchQueue.main.async {
                            isCurrentlyEditing = editing
                            if editing { onStartEdit(itemID) }
                            else {
                                tapPoint = nil
                                onEndEdit(itemID, shouldCreateNewItem)
                            }
                        }
                    },
                    returnKeyType: isLastActiveItem && !editingTitle.isEmpty ? .next : .done,
                    onContentChange: { newTitle in
                        guard !item.isCompleted else { return }
                        onTitleChange(itemID, newTitle)
                    },
                    uiAccessibilityIdentifier: "item-text-\(itemID.uuidString)",
                    initialCursorPoint: tapPoint
                )
                .focused($focusedField, equals: .item(itemID))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !item.isCompleted {
                itemProxy
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        tapPoint = value.location
                        onSelect(itemID)
                        focusedField = .item(itemID)
                    })
            } else {
                itemProxy
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, ItemRowMetrics.contentVerticalPadding)
        .padding(.trailing, ItemRowMetrics.contentHorizontalPadding)
        .padding(
            .leading,
            item.isCompleted ? ItemRowMetrics.completedLeadingPadding : ItemRowMetrics.activeLeadingPadding
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            // .onTapGesture (not .simultaneousGesture) lets the child Button suppress this
            // gesture for its own hit area, so circle button taps don't also fire here.
            // If tapping a completed row while another row is being edited, preserve
            // the current focus/selection.
            if item.isCompleted,
               let field = focusedField,
               case .item(let id) = field,
               id != itemID
            {
                return
            }
            if item.isCompleted {
                withAnimation { onToggle(itemID) }
            } else {
                tapPoint = nil
                onSelect(itemID)
                focusedField = .item(itemID)
            }
        }
        .background(cardBackground)
        .overlay(alignment: .leading) {
            if !item.isCompleted {
                Rectangle()
                    .fill(cachedAccentColor)
                    .frame(width: ItemRowMetrics.accentBarWidth)
            }
        }
        .onAppear {
            editingTitle = item.title
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: item.title) { _, newValue in
            if !isCurrentlyEditing {
                editingTitle = newValue
            }
        }
        .onChange(of: index) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: totalItems) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: colorThemeRaw) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .itemSwipeGesture(
            isDragging: $isDragging,
            isEditing: focusedField == .item(itemID),
            isSwiping: $isSwiping,
            swipeOffset: $swipeOffset,
            swipeDirection: $swipeDirection,
            isTriggered: $isSwipeTriggered,
            completeColor: cachedAccentColor,
            onComplete: { onToggle(itemID) },
            onDelete: { onDelete(itemID) }
        )
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                swipeOffset = 0
                swipeDirection = .none
                isSwipeTriggered = false
            }
        }
        .clipShape(ItemCardModifier.shape)
        .overlay(
            isSelected && !item.isCompleted
                ? ItemCardModifier.shape
                    .strokeBorder(cachedAccentColor.opacity(0.40), lineWidth: 2)
                : nil
        )
    }

    private var isEditing: Bool {
        focusedField == .item(itemID)
    }

    @ViewBuilder
    private var itemProxy: some View {
        if item.isCompleted {
            Text(editingTitle)
                .font(ItemRowMetrics.bodySUI)
                .foregroundStyle(.secondary)
                .strikethrough(true, color: .secondary)
                .accessibilityIdentifier("item-text-\(itemID.uuidString)")
        } else {
            Text(editingTitle)
                .font(ItemRowMetrics.bodySUI)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("item-text-\(itemID.uuidString)")
        }
    }

    @MainActor
    private func computeAccentColor() -> Color {
        guard !item.isCompleted else { return .clear }
        return cachedItemColor(forIndex: index, total: totalItems, theme: colorTheme)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if item.isCompleted {
            isSelected ? Color.completedSelected : Color.clear
        } else if isSelected {
            Color.itemCard.overlay(cachedAccentColor.opacity(0.15))
        } else {
            Color.itemCard
        }
    }
}
