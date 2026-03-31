import SwiftUI

struct ItemRowView: View {
    let item: ItemValue
    let itemID: UUID
    let index: Int
    let totalItems: Int
    let isSelected: Bool
    let onToggle: (UUID) -> Void
    let onTitleChange: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onSelect: (UUID) -> Void
    let onStartEdit: (UUID) -> Void
    let onEndEdit: (UUID, _ shouldCreateNewItem: Bool) -> Void
    let onPaste: (String) -> Void
    @FocusState.Binding var focusedField: FocusField?

    @AppStorage("colorTheme") private var colorThemeRaw = 0
    private var colorTheme: ColorTheme { ColorTheme(rawValue: colorThemeRaw) ?? .pilbara }

    @State private var editingTitle: String = ""
    @State private var isCurrentlyEditing: Bool = false
    @State private var cachedAccentColor: Color = .clear

    private let horizontalPadding: CGFloat = 16
    private let checkboxTextSpacing: CGFloat = 12
    @ScaledMetric private var checkboxSize: CGFloat = 20

    private var dividerInset: CGFloat {
        horizontalPadding + checkboxSize + checkboxTextSpacing
    }

    @MainActor
    private func computeAccentColor() -> Color {
        guard !item.isCompleted else { return .clear }
        return cachedItemColor(forIndex: index, total: totalItems, theme: colorTheme)
    }

    init(
        item: ItemValue,
        itemID: UUID,
        index: Int = 0,
        totalItems: Int = 1,
        isSelected: Bool,
        focusedField: FocusState<FocusField?>.Binding,
        onToggle: @escaping (UUID) -> Void,
        onTitleChange: @escaping (UUID, String) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onSelect: @escaping (UUID) -> Void,
        onStartEdit: @escaping (UUID) -> Void = { _ in },
        onEndEdit: @escaping (UUID, _ shouldCreateNewItem: Bool) -> Void = { _, _ in },
        onPaste: @escaping (String) -> Void = { _ in }
    ) {
        self.item = item
        self.itemID = itemID
        self.index = index
        self.totalItems = totalItems
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onTitleChange = onTitleChange
        self.onDelete = onDelete
        self.onSelect = onSelect
        self.onStartEdit = onStartEdit
        self.onEndEdit = onEndEdit
        self.onPaste = onPaste
        _focusedField = focusedField
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button {
                onToggle(itemID)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .font(.system(size: 17))
                    .fontWeight(.thin)
            }
            .buttonStyle(.borderless)
            .alignmentGuide(.firstTextBaseline) { d in
                d[VerticalAlignment.center] + 5
            }
            .accessibilityIdentifier("item-checkbox")
            .accessibilityValue(item.isCompleted ? "checkmark.circle.fill" : "circle")

            ClickableTextField(
                text: $editingTitle,
                isCompleted: item.isCompleted,
                onEditingChanged: { editing, shouldCreateNewItem in
                    isCurrentlyEditing = editing
                    if editing {
                        onStartEdit(itemID)
                    } else {
                        onEndEdit(itemID, shouldCreateNewItem)
                    }
                },
                itemID: itemID,
                onContentChange: { newTitle in
                    guard !item.isCompleted else { return }
                    onTitleChange(itemID, newTitle)
                }
            )
            .focused($focusedField, equals: .item(itemID))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(
                isCurrentlyEditing ? "item-textfield" : "item-text-\(itemID.uuidString)")
        }
        .padding(.top, 4)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(itemID)
        }
        .background(selectionBackground)
        .overlay(alignment: .leading) {
            // Colored accent bar on the left edge
            Rectangle()
                .fill(cachedAccentColor)
                .frame(width: 4)
                .padding(.vertical, 1)
        }
        .overlay(alignment: .bottom) {
            // Hairline border between rows, inset to align with text
            // Only show for active (non-completed) items
            if !item.isCompleted {
                Rectangle()
                    .fill(.separator)
                    .frame(height: 0.5)
                    .padding(.leading, dividerInset)
            }
        }
        .overlay {
            if isSelected && !item.isCompleted {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(cachedAccentColor.opacity(0.40), lineWidth: 2)
            }
        }
        .contextMenu {
            Button(item.isCompleted ? "Mark as Incomplete" : "Mark as Complete") {
                onToggle(itemID)
            }
            Divider()
            Button("Cut") {
                cutToPasteboard()
            }
            Button("Copy") {
                copyToPasteboard()
            }
            Button("Paste") {
                pasteFromPasteboard()
            }
            .disabled(item.isCompleted)
            Divider()
            Button("Delete", role: .destructive) {
                onDelete(itemID)
            }
        }
        .onChange(of: item.title) { _, newValue in
            if !isCurrentlyEditing {
                editingTitle = newValue
            }
        }
        .onChange(of: colorThemeRaw) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: index) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onChange(of: totalItems) { _, _ in
            cachedAccentColor = computeAccentColor()
        }
        .onAppear {
            editingTitle = item.title
            cachedAccentColor = computeAccentColor()
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            if item.isCompleted {
                Color(nsColor: .controlBackgroundColor)
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    private func cutToPasteboard() {
        copyToPasteboard()
        onDelete(itemID)
    }

    private func copyToPasteboard() {
        guard !item.title.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.title, forType: .string)
    }

    private func pasteFromPasteboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        onPaste(string)
    }
}
