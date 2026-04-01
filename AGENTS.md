# Repository Guidelines

Listless is a to-do list app for Apple platforms. It is intended to run on iPhone, iPad, Mac, and Apple Watch.

## Project Structure & Module Organization
- `Listless.xcodeproj` coordinates three app targets: "Listless iOS" (iPhone/iPad), "Listless macOS" (native Mac), and "Listless watchOS" (Apple Watch), all sharing code from the `Listless/` directory.
- `project.yml` defines the Xcode project structure for XcodeGen; run `xcodegen generate` to regenerate the project after modifying it.
- `Listless/Models` owns `ItemEntity` (NSManagedObject), `ItemValue` (plain struct snapshot of `ItemEntity` for safe use outside Core Data), `ItemStore` (plain `final class` wrapping Core Data operations), and Core Data model definitions; keep CloudKit configuration inside `Listless/Sync`.
- `Listless/Extensions` holds extensions on shared types; `ItemListView+Logic.swift` and `ItemListView+SyncUI.swift` are extensions on `ItemListViewProtocol` (not the concrete struct) so SourceKit can resolve them unambiguously across both targets.
- `Listless/Helpers` holds shared non-view supporting code (`AccentColor`, `KeyboardNavigationModifier`, `ItemListTypes`, `ItemListViewProtocol`). `AccentColor.swift` defines `ColorTheme` (cases: `pilbara`, `collaroy`) with HSB gradient stops and a cached color interpolation function (`cachedItemColor`); both platforms read the selected theme from `@AppStorage("colorThemeRaw")`. `ItemListTypes.swift` defines the `FocusField` and `DragState` enums as top-level types (shared by both platform `ItemListView` structs) and the `FocusStateData` struct that manages selection state — including `inactiveSelections` for discontinuous selections created by Cmd+Click toggle on macOS. `ItemListViewProtocol.swift` defines the `@MainActor ItemListViewProtocol` that both structs conform to, declaring the shared property contract (`items`, `store`, `syncMonitor`, `managedObjectContext`, `focusedField`, `fState`, `dragState`, `draftPlacement`, `draftTitle`, `didStartDrag()`, `revealDraftItemUI(at:animated:)`, `clearDraftItemUI(at:hasTitle:)`).
- `ListlessiOS/` contains the iOS app entry point, organised into three subdirectories:
  - `Views/` — iOS-specific view components (`ItemListView`, `ItemRowView`, `DraftRowView`, `PullToCreate`, `PullToClear`, `UndoToast`, `SettingsView`, `SyncDiagnosticsView`, `AboutView`).
  - `Helpers/` — gesture recognizers, UIKit representables, color definitions, platform-shim view modifiers, and tutorial seeding (`TappableTextField`, `ItemRowSwipeGesture`, `ItemRowDragGesture`, `AppColors`, `HoverCursorModifier`, `TutorialSeeder`, `ItemCardModifier`, `ItemRowMetrics`, `FPSOverlay`, etc.).
  - `Extensions/` — platform-specific extensions on shared types (`ItemListView+NavigationHeader`, `ItemListView+Toolbar`, `ItemListView+PullToCreate`, `ItemListView+PullToClear`, `ItemListView+PullGestures`, `ItemListView+Drag`, `ItemListView+Undo`).
- `ListlessMac/` contains the macOS app entry point with the same three-subdirectory structure as `ListlessiOS/` (`Views/` includes `ItemListView`, `ItemRowView`, `SyncDiagnosticsView`; `Helpers/` includes `AppCommands`, `AppColors`, `ClickableTextField`, `BackgroundClickMonitor`, `ItemRowDragGesture`, etc.).
- `ListlessWatch/` contains the watchOS app entry point and a simplified `Views/` subdirectory (`ItemListView`, `ItemRowView`). The watchOS target selectively includes only `Listless/Models`, `Listless/Sync`, and `Listless/Helpers/AccentColor.swift` — it does not use `ItemListViewProtocol` or the shared extensions. The watch app is read-only (no creating, editing, reordering, or deleting) and supports toggling item completion only.
- `Tests/Unit` covers ordering, editing, persistence, and CloudKit error classification; `Tests/UI` holds iOS and macOS UI tests; `Tests/Support` holds shared test helpers and fixtures.

## Deployment Targets
- iOS 18.0, macOS 14.0, watchOS 11.0 (defined in `project.yml`).
- Use platform APIs available at these floors freely; no need for `@available` checks or older-OS fallbacks.

## Build, Test, and Development Commands
- `xed .` launches the project in Xcode.
- `xcodegen generate` regenerates `Listless.xcodeproj` from `project.yml`.
- `xcodebuild -scheme "Listless macOS" -destination 'platform=macOS' build` builds the native macOS app.
- `xcodebuild -scheme "Listless iOS" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build` builds the iOS app (includes embedded watchOS app).
- `xcodebuild -scheme "Listless watchOS" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=11.5' build` builds the watchOS app standalone.
- `xcodebuild test -scheme "Listless iOS" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'` runs unit + UI tests.
- `Scripts/test-ios-ui.sh` and `Scripts/test-macos-ui.sh` run platform-specific UI tests.
- `swift format lint --recursive .` must be clean before opening a PR.

## App Store Connect Release
- Publish scripts live in `Scripts/` and handle archiving, signing, exporting, and uploading via `xcrun iTMSTransporter`.
- Secrets (team ID, API key ID, issuer ID, p12 passwords) are sourced from `.asc/secrets.sh`, which is gitignored.
- Signing uses a temporary keychain (created and cleaned up by the scripts) with distribution `.p12` files from `.asc/`. No login keychain unlock is required.
- App Store Connect API auth uses a `.p8` key file in `.asc/`, referenced by `$KEY_ID` from `secrets.sh`.
- Build numbers come from scheme pre-action (`YEAR.COMMIT_COUNT`), so archiving from latest `HEAD` produces the latest-commit build.
- Internal testers automatically receive all builds; no explicit group assignment is needed.
- Both scripts archive with signing enabled to preserve entitlements (CloudKit, App Sandbox). Do not disable code signing during the archive step.

### iOS
- Run `Scripts/publish-ios.sh` from the repo root.
- Pass `--check` to archive, export, and inspect entitlements without uploading.
- Archives with signing, then exports an IPA with manual signing (`iPhone Distribution` cert, `Listless iOS Distribution` + `Listless watchOS Distribution` profiles).
- The watchOS app is embedded in the iOS app bundle and uploaded together.

### macOS
- Run `Scripts/publish-macos.sh` from the repo root.
- Archives with signing, then exports a `.pkg` with manual signing (`3rd Party Mac Developer Application` + `3rd Party Mac Developer Installer` certs, `Listless macOS Distribution` profile).

## Build Number
- `CFBundleVersion` in all Info.plist files uses `$(CURRENT_PROJECT_VERSION)`, sourced from `Generated/BuildNumber.xcconfig`.
- Each scheme has a build pre-action that runs `git log`/`git rev-list` to compute `YEAR.COMMIT_COUNT` and writes it to the xcconfig before the build starts.
- Scheme pre-actions are not subject to `ENABLE_USER_SCRIPT_SANDBOXING`, which is why this lives in the scheme rather than a build phase script.
- `Generated/BuildNumber.xcconfig` is gitignored; the scheme pre-action creates it before every build.

## Coding Style & Naming Conventions
- Use SwiftUI + Observation (`@Observable`), indent four spaces, and prefer trailing commas in builders.
- Models are nouns (`ItemEntity`), views end with `View`, and services end with `Service`; keep async methods verb-first (`syncItems()`).
- Centralize state in `@Observable ItemStore` that wraps Core Data operations; mutations flow through intent methods like `complete(itemID:)`.
- `ItemStore.createItem(title:atBeginning:sortOrder:)` accepts an `atBeginning` flag (default `false`); when `true` assigns `minSortOrder - 1000` to prepend the item before all existing active items. An optional `sortOrder` parameter allows callers (e.g. `TutorialSeeder`) to specify an explicit sort position. `createItem` does **not** save — callers must call `store.save()` explicitly when they want to persist. This keeps empty placeholder items (from background tap or Return) in-memory only until the user types, avoiding iCloud sync of transient objects.
- Completed items display below active ones; never reorder or edit them in-place.
- For selection state in ForEach contexts, use computed Bool values + callbacks rather than passing @Binding to children (avoids SwiftUI update issues).
- Both code and user-facing text use "item" terminology. The Core Data entity name remains `TaskItem` (via `@objc(TaskItem)`) to avoid CloudKit migration, but the Swift class is `ItemEntity`.

## Sync & Data Guidelines
- Core Data with `NSPersistentCloudKitContainer` handles persistence and iCloud sync; configured in `PersistenceController` within `Listless/Sync`.
- `ItemEntity` is an `NSManagedObject` subclass (Core Data entity name: `TaskItem`, kept via `@objc(TaskItem)` to preserve CloudKit compatibility) with auto-updating `updatedAt` timestamp via `willSave()`.
- CloudKit container identifier is `iCloud.net.inqk.listless`; entitlements are defined in `project.yml` and generated by XcodeGen.
- Keep CloudKit configuration and Core Data setup inside `Listless/Sync`; exposing raw Core Data contexts elsewhere is discouraged.
- `KeyValueSyncBridge` (`Listless/Sync/KeyValueSyncBridge.swift`) bridges `@AppStorage` keys to `NSUbiquitousKeyValueStore` for iCloud sync of user preferences. Currently syncs `"listName"` (the customisable list title) and `"colorTheme"` (the selected accent colour theme). On startup it pulls cloud values into `UserDefaults`; bidirectional observation keeps the two stores in sync with an `isSyncing` flag to prevent feedback loops. To sync additional preferences, add the key to the `keys` set in `ListlessiOSApp.init()`.
- When adding fields to the Core Data model, update `Listless.xcdatamodeld`, add migration mappings if needed, and document changes in `Docs/Schema.md`.

## Testing Guidelines
- Use Swift Testing framework with `@Test` macro and `#expect` assertions.
- Organize tests into `@Suite` groupings with descriptive names.
- Use natural function names that describe what's being tested (no `test` prefix required).
- Leverage parameterized tests with `@Test(arguments: [...])` for testing multiple scenarios.
- Maintain ≥80% coverage for `ItemStore` and Core Data operations, especially reordering edge cases and merge conflict resolution.
- UI tests must verify keyboard entry flows: pressing Return creates an item then focuses the new empty row; tapping whitespace also starts entry.
- Use `PersistenceController(inMemory: true)` for isolated test environments with Core Data.

## macOS Implementation: SwiftUI vs AppKit
- **Current implementation**: macOS uses SwiftUI (same as iOS)
- **AppKit migration attempt** (Feb 2026): Attempted for better drag-and-drop control, reverted due to state management complexity, focus issues, and selection bugs. SwiftUI's declarative patterns proved more maintainable for this app. The AppKit code has since been removed.

## Menu Customisation (both platforms)
- **Do not use SwiftUI's `Commands` API** — broken on macOS 15 (dividers don't render, `CommandGroup(replacing:)` causes Window menu jitter) and on iPadOS (arrow key glyphs render as "?", `@FocusedValue` propagation fails when a UIKit view is first responder).
- **Both platforms use native menu APIs** with a shared coordinator pattern: action closures + enabled-state booleans updated by `ItemListView.updateWindowCoordinator()` (macOS) / `ItemListView.updateMenuCoordinator()` (iOS).
- **Adding a new key binding** requires four touch points per platform: (1) coordinator — add action closure + enabled flag, (2) selector/action protocol — add the `@objc` method, (3) menu definition — register the key command in the right menu, (4) `updateWindowCoordinator()`/`updateMenuCoordinator()` — wire up the action and enabled state.

### macOS
- **Menus are fully AppKit-owned** in `AppDelegate.installMainMenu()` (`ListlessMac/ListlessMacApp.swift`), assigned directly via `NSApp.mainMenu`.
- **No runtime menu patching**: do not use `NSMenu.didAddItemNotification`/tag-guard patch logic for command setup in the current architecture.
- **`WindowCoordinator`** (`ListlessMac/Helpers/AppCommands.swift`) bridges SwiftUI state to AppKit. One instance per window, stored in `AppDelegate`'s `NSMapTable<NSWindow, WindowCoordinator>`. Handles menu actions/enabled state (surfaced via `NSMenuItemValidation.validateMenuItem`) and focus gating (see macOS focus gating below).
- **Command shortcuts are canonical in AppKit menus** (e.g. New Item, Move Up/Down, Mark Completed, Delete). Avoid duplicating those command shortcuts in `ItemListView.keyboardNavigation(...)`.
- **Selector style**: prefer typed `#selector(...)` where available; use `MenuSelectors` constants for string-based selectors that lack typed Swift symbols.
- **Window menu**: keep explicit baseline items in `installMainMenu()` and let `NSApp.windowsMenu` provide system-managed dynamic window list behavior.
- **Theme menu**: `installMainMenu()` builds a View > Theme submenu from `ColorTheme.displayOrder`; selection is persisted via `UserDefaults` key `"colorThemeRaw"` and handled by `handleThemeSelection(_:)` on `WindowCoordinator`.

### iOS (iPad)
- **Menus use UIKit's `buildMenu(with:)`** in `IOSAppDelegate` (`ListlessiOS/ListlessiOSApp.swift`), inserting `UIKeyCommand` items into standard `.file` and `.edit` menus so the iPad keyboard shortcut overlay groups them correctly.
- **`IOSMenuCoordinator`** (`ListlessiOS/Helpers/AppCommands.swift`) bridges SwiftUI state to UIKit. `IOSMenuActions` protocol declares `@objc` action selectors; `KeyCaptureView` (the first responder in `KeyCommandBridge`) conforms and dispatches to the coordinator.
- **Conditional availability**: `KeyCaptureView.canPerformAction(_:withSender:)` checks coordinator enabled flags; commands are greyed out in the overlay when conditions aren't met (e.g. Move Up disabled when selected item is first).
- **Plain (unmodified) key commands** (Up, Down, Space, Return, Delete) are still handled by `KeyCommandBridge`'s `keyCommands` property with `wantsPriorityOverSystemBehavior = true`. Command-modified shortcuts go through `buildMenu` → responder chain → `KeyCaptureView` action methods.

## iOS Implementation Notes
- **Platform-specific inits**: iOS and macOS `ItemRowView` have diverged (iOS takes `isDragging: Binding<Bool>`). When adding new parameters, update both `ItemRowView` inits and both `ItemListView` bodies. The watchOS `ItemRowView` is independent and much simpler (tap-to-toggle only).
- **Appearance override**: Use `UIWindow.overrideUserInterfaceStyle` in `ListlessiOSApp`, not `.preferredColorScheme()` (which doesn't properly revert to nil in sheets).
- **Focus guard for overlays**: The `onChange(of: focusedFieldBinding)` handler skips "reclaim focus to `.scrollView`" logic when an overlay (sheet or alert) is presented, preventing focus theft from overlay TextFields. This is controlled by `InteractionStateData.isShowingOverlay`, a computed property that combines `isShowingSettings`, `isShowingSyncDiagnostics`, and `isShowingRenameAlert`. When adding a new sheet or alert with a text field, add its presentation flag to `isShowingOverlay`.
- **App icon in About screen**: Use `Image("AboutIcon")` from `Media.xcassets/AboutIcon.imageset` — `.appiconset` images can't be loaded via `Image()` in SwiftUI.
- **iOS color system**: `ListlessiOS/Helpers/AppColors.swift` defines `Color.outerBackground` and `Color.itemCard`. Adjust these two values to shift the palette.
- **Pull-to-create/clear**: Scroll gesture handling is in `.pullGestures()` (`ItemListView+PullGestures.swift`); visual indicators are in `ItemListView+PullToCreate.swift` and `ItemListView+PullToClear.swift`. The macOS `body` omits all of these. The pull-to-create indicator and the draft prepend row are separate siblings in the VStack (not a ZStack overlay) — the indicator collapses to zero height when the draft row appears. `revealPhantomRow()` directly sets up draft placement and focus without calling `createNewItemAtTop()`. Row spacing uses explicit `.padding(.bottom, rowGap)` on each row rather than VStack `spacing` (which is set to 0).
- **Haptics**: Gated behind `@AppStorage("hapticsEnabled")`. Pull-to-create/clear thresholds and drag-start use `.light` impact weight. Draft creation uses `.sensoryFeedback` on a `draftCount` trigger.
- **Overflow menu**: iOS uses an overflow menu (ellipsis button) in the navigation header (`ItemListView+NavigationHeader.swift`) instead of a standalone settings button. The menu contains Rename List, Delete All, and Settings. On iOS 26+ the menu label uses `.glassEffect(.clear)`; on older versions it falls back to an `ellipsis.circle` SF Symbol with `.buttonStyle(.plain)`. Rename List presents an alert with a text field (`isShowingRenameAlert`); Delete All presents a destructive confirmation alert (`isShowingDeleteAllAlert`).
- **Tutorial**: On first launch, `TutorialSeeder` populates the list with instructional items (swipe, drag, pull gestures). Gated by `@AppStorage("didCompleteTutorial")`; Settings includes a reset option. Tutorial seeding runs in `ListlessiOSApp.init()` and is skipped during UI tests.
- **Selection on iOS/iPadOS is intentionally limited**: iOS supports single-item cursor navigation via arrow keys (for marking complete/incomplete) but does not support multi-select, Select All (Cmd+A), or Cmd+Click toggling. Full selection semantics (range select, multi-select, select all) are macOS-only. Do not add selection features to the iOS target.

## SwiftUI Implementation Notes
- **ItemListView architecture**: Declared separately per platform (`ListlessiOS/Views/ItemListView.swift`, `ListlessMac/Views/ItemListView.swift`, `ListlessWatch/Views/ItemListView.swift`). iOS and macOS conform to `ItemListViewProtocol`; watchOS is standalone (does not use the protocol or shared extensions). State is grouped by concern: `fState` (focus), `iState` (interaction), `pState` (pull gestures, iOS only), `isDragging` (iOS only, separate `@State` to avoid dirtying `iState`), and `layoutStorage` (non-reactive `LayoutStorage` class holding `rowFrames` and `contentBottomY` — a plain class under `@State` so SwiftUI holds a stable reference without tracking field mutations). macOS uses `tState` (item/view-local) instead of `pState`/`isDragging`/`layoutStorage`. Shared logic lives in `ItemListView+Logic.swift` as an extension on `ItemListViewProtocol`. Because `private` is file-scoped, stored properties accessed from extensions must be `internal`. Platform-specific extensions that would return `EmptyView()` on the other platform are simply omitted.
- **Selection pattern**: Parent owns `@State var selectedItemID`; children receive `isSelected: Bool` + `onSelect: () -> Void` callback (avoids SwiftUI ForEach update issues with @Binding). macOS supports Cmd+Click to toggle individual items in/out of the selection, creating discontinuous selections tracked via `FocusStateData.inactiveSelections`. Shift+Arrow after Cmd+Click preserves inactive items and merges them when the active range becomes adjacent. Read modifiers via `NSApp.currentEvent?.modifierFlags` (not the `NSEvent.modifierFlags` class property) so CGEvent-based UI tests can set modifier flags on synthesised mouse events.
- **Focus management**: Single `@FocusState` enum (`FocusField` in `ItemListTypes.swift`) with `.item(UUID)` and `.scrollView` cases. Never use multiple @FocusState variables for related focus. Keyboard handlers return `.ignored` when wrong focus state.
  - **iOS focus cleanup**: On iOS, always dismiss focus by setting `focusedField = nil`, never directly to `.scrollView`. The `onChange(of: focusedFieldBinding)` handler intercepts `nil` to run cleanup (e.g. `deleteIfEmpty` for empty items) before redirecting to `.scrollView`. Skipping `nil` desyncs SwiftUI focus state from UIKit first responder and can cause crashes.
  - **Pending focus**: Set both `pendingFocus` and `focusedField` in `createNewItem()`. Do NOT resolve in `.onAppear` (race conditions). Clear `pendingFocus` in `startEditing()`. Guard `deleteIfEmpty()` against `pendingFocus` matches.
  - **macOS focus gating via `WindowCoordinator.allowedFocusTarget`**: When Return/Escape ends editing via `makeFirstResponder(nil)`, SwiftUI processes the `@FocusState` change asynchronously. During reconciliation it can traverse the view hierarchy and make the first `NSTextField` become first responder, overriding the `.scrollView` assignment. The per-window `allowedFocusTarget` property on `WindowCoordinator` prevents this: `doCommandBy` sets it to `.scrollView` before `makeFirstResponder(nil)`, and `ClickableNSTextField.acceptsFirstResponder` checks it — rejecting focus unless the field matches the allowed target. Each `ClickableNSTextField` carries an `itemID` for this comparison. The gate is cleared in `onChange(of: focusedFieldBinding)` once `newValue` is non-nil (reconciliation complete). When `pendingFocus` is set (e.g. revealing a draft row), the gate is updated to allow that specific target, and `ClickableNSTextField.viewDidMoveToWindow()` claims focus when the view enters the window hierarchy (handles the case where the NSView doesn't exist yet when focus is requested).
- **Text editing**: iOS uses `TappableTextField` (UIViewRepresentable wrapping `UITextView`); macOS uses `ClickableTextField` (NSViewRepresentable wrapping `NSTextField`). Both use delegate/coordinator patterns to bridge to SwiftUI. Key gotcha: `onEditingChanged` callbacks from UIKit may arrive during a SwiftUI update pass — defer via `DispatchQueue.main.async`. On iOS, `TappableTextField` defers `isDragging`-driven changes to `isEditable`/`isSelectable` via the coordinator's `setDragging(_:)` method (called from `Task { @MainActor in }` in `updateUIView`) — setting these properties synchronously in `updateUIView` causes UITextView to call `invalidateIntrinsicContentSize()`, creating a layout-to-state backward edge that triggers AttributeGraph cycle warnings.
- **Drag-and-drop**: Both platforms maintain `visualOrder` during drag and commit via `store.moveItem()` on release. macOS uses a custom `ItemRowDragGesture` ViewModifier (`ListlessMac/Helpers/ItemRowDragGesture.swift`); iOS uses `UIGestureRecognizerRepresentable` (`ItemRowDragGesture`) with a long-press recognizer. The drag gesture is gated so it won't activate on a focused (editing) row — prevents the drag from stealing touches from the text cursor/loupe. The gesture's delegate uses `shouldBeRequiredToFailBy` to make UITextView gestures wait for the drag to fail, preventing the loupe from appearing during drag-reorder. Swipe gestures (`ItemRowSwipeGesture`) are also disabled on the focused row via an `isEditing` parameter, so horizontal swiping doesn't interfere with text selection.
- **Keyboard navigation**: macOS uses dictionary-based keybindings in `KeyboardNavigationModifier.swift`. iOS uses `KeyCommandBridge` (UIViewRepresentable) because iPadOS `@FocusState` silently fails with hardware keyboards — the iOS `body` does **not** use `.focusable()`, `.focused(equals: .scrollView)`, or `.keyboardNavigation()`.
- Avoid `Spacer` inside `ScrollView` (causes unwanted scrollbar).
- **Escape hatches** (`GeometryReader`, `PreferenceKey`, `UIViewRepresentable`/`NSViewRepresentable`): only after exhausting SwiftUI-native alternatives (`.frame`, `.overlay`, `.background`, `alignmentGuide`).

## Commit & Pull Request Guidelines
- Do not create commits; the user handles version control.
- PR descriptions should summarize scope, list test commands, link issues, and attach screenshots or screen recordings for UI changes.
- Call out Core Data model or CloudKit schema updates explicitly and describe any expected migration impact.
