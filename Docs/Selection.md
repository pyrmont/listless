# Findings: Cmd+Click Toggle for Multi-Select (Issue 1)

## Current Implementation

The macOS selection model uses `FocusStateData` in
`Listless/Helpers/TaskListTypes.swift` with:

- `selectedTaskIDs: Set<UUID>` — the full set of selected task IDs
- `anchorTaskID: UUID?` — fixed end of a Shift+Arrow range
- `cursorTaskID: UUID?` — moving end of the range
- `selectedTaskID: UUID?` — convenience getter/setter that resets to
  single-element selection

`extendSelection(to:displayOrder:)` computes a contiguous range from anchor to
cursor and replaces `selectedTaskIDs` entirely. This means the current model
has no concept of discontinuous selections.

Shift+Click is handled in `TaskListView+Logic.swift` via `selectTask(_:extendSelection:)`.
The macOS `TaskListView` body checks `NSEvent.modifierFlags.contains(.shift)` and
passes `extendSelection: true`.

Shift+Up/Down are `navigateUpExtend()`/`navigateDownExtend()` in `TaskListView+Logic.swift`.
They move the cursor one step and call `extendSelection(to:displayOrder:)`.

## Proposed Cmd+Click Behaviour

Cmd+Click should toggle individual items in and out of a multi-selection.

### State Model

After a Cmd+Click, the state consists of:

- **anchor** — set to the item immediately below the Cmd+Clicked item
- **cursor** — reset to the same position as anchor
- **inactive selections** — all other selected items outside the anchor-cursor
  range (these are carried forward from the previous selection)

The visible selection is: `inactive ∪ range(anchor, cursor)`.

### Shift+Arrow After Cmd+Click

Shift+Up/Down moves the cursor. The selection is recomputed as
`inactive ∪ range(anchor, cursor)`. The range flips direction when the cursor
crosses the anchor.

**Merge rule**: when the active range becomes adjacent to (or overlaps with) an
inactive range, the inactive items are absorbed into the active range and the
cursor jumps to the far end of the merged region (away from the anchor). After
a merge, the selection is fully contiguous and subsequent Shift+Arrow presses
behave as normal anchored selection.

### Worked Example

Starting list: A, B, C, D, E, F, G, H, I

| Step | Action         | Cursor | Anchor | Active Range | Inactive | Selection   |
|------|----------------|--------|--------|--------------|----------|-------------|
| 1    | Select D-G     | G      | D      | {D,E,F,G}   | {}       | {D,E,F,G}  |
| 2    | Cmd+Click E    | F      | F      | {F}          | {D,G}   | {D,F,G}    |
| 3    | Shift+Up       | E      | F      | {E,F}        | {D,G}   | {D,E,F,G}  |

Wait — this doesn't match. The user's test showed step 2 → step 3 as
{D,F,G} → {D,F} with Shift+Up. That means the cursor after Cmd+Click was
at G (the previous cursor), not reset to the anchor.

**Corrected model**: after Cmd+Click, the cursor stays at its previous position
(G), and the anchor moves to the item below the clicked item (F).

| Step | Action         | Cursor | Anchor | Active Range | Inactive | Selection     |
|------|----------------|--------|--------|--------------|----------|---------------|
| 1    | Select D-G     | G      | D      | {D,E,F,G}   | {}       | {D,E,F,G}    |
| 2    | Cmd+Click E    | G      | F      | {F,G}        | {D}      | {D,F,G}      |
| 3    | Shift+Up       | F      | F      | {F}          | {D}      | {D,F}        |
| 4    | Shift+Down     | G      | F      | {F,G}        | {D}      | {D,F,G}      |
| 5    | Shift+Up       | F      | F      | {F}          | {D}      | {D,F}        |
| 6    | Shift+Up       | E      | F      | {E,F}        | {D}*     | {D,E,F}      |
| 7    | Shift+Up       | C      | F      | {C,D,E,F}   | {}       | {C,D,E,F}    |
| 8    | Shift+Down     | D      | F      | {D,E,F}     | {}       | {D,E,F}      |
| 9    | Shift+Down     | E      | F      | {E,F}       | {}       | {E,F}        |
| 10   | Shift+Down     | F      | F      | {F}         | {}       | {F}          |

*At step 6, the active range {E,F} becomes adjacent to inactive {D}. Merge
occurs: inactive is cleared and the cursor jumps from E to D (the far end of
the merged region, away from the anchor). This is why step 7's Shift+Up moves
the cursor from D to C, not from E to D.

### Edge Cases Still to Decide

- **Cmd+Click on the bottom-most item**: there is no item below to anchor to.
  Options: anchor to the clicked item itself, or anchor to the item above.
- **Multiple Cmd+Clicks**: each Cmd+Click sets the anchor to the item below the
  clicked item; cursor stays at its previous position. The inactive set is
  whatever is selected outside the active range. (This is a simplification;
  actual Finder behaviour in macOS 15 varies depending on whether you deselect
  going up vs down the list.)
- **Cmd+Click to add** (clicking an unselected item): needs testing. Presumably
  the item is added to the selection and anchor/cursor update the same way.
