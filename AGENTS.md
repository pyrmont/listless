# Repository Guidelines

## Project Structure & Module Organization
- `Listless.xcodeproj` coordinates two app targets: "Listless iOS" (iPhone/iPad) and "Listless macOS" (native Mac), both sharing code from the `Listless/` directory.
- `project.yml` defines the Xcode project structure for XcodeGen; run `xcodegen generate` to regenerate the project after modifying it.
- `Listless/Models` owns `TaskItem` (NSManagedObject), `TaskStore` (plain `final class` wrapping Core Data operations), and Core Data model definitions; keep CloudKit configuration inside `Listless/Sync`.
- `Listless/Extensions` holds extensions on shared types; `TaskListView+Logic.swift` and `TaskListView+SyncUI.swift` are extensions on `TaskListViewProtocol` (not the concrete struct) so SourceKit can resolve them unambiguously across both targets.
- `Listless/Helpers` holds shared non-view supporting code (`AccentColor`, `KeyboardNavigationModifier`, `TaskListTypes`, `TaskListViewProtocol`). `TaskListTypes.swift` defines the `FocusField` and `DragState` enums as top-level types (shared by both platform `TaskListView` structs). `TaskListViewProtocol.swift` defines the `@MainActor TaskListViewProtocol` that both structs conform to, declaring the shared property contract (`tasks`, `store`, `syncMonitor`, `managedObjectContext`, `focusedField`, `selectedTaskID`, `pendingFocus`, `dragState`, `didStartDrag()`).
- `ListlessiOS/` contains the iOS app entry point, organised into three subdirectories:
  - `Views/` — iOS-specific view components (`TaskListView`, `TaskRowView`, `PullToCreate`, `PullToClear`, `UndoToast`, `SettingsView`, `SyncDiagnosticsView`, `AboutView`).
  - `Helpers/` — gesture recognizers, UIKit representables, color definitions, and platform-shim view modifiers (`TappableTextField`, `TaskRowSwipeGesture`, `TaskRowDragGesture`, `AppColors`, `HoverCursorModifier`, etc.).
  - `Extensions/` — platform-specific extensions on shared types (`TaskListView+NavigationHeader`, `TaskListView+Toolbar`, `TaskListView+PullToCreate`, `TaskListView+PullToClear`, `TaskListView+PullGestures`, `TaskListView+Drag`, `TaskListView+Undo`).
- `ListlessMac/` contains the macOS app entry point with the same three-subdirectory structure as `ListlessiOS/` (`Views/` includes `TaskListView`); an excluded `AppKit/` subdirectory holds the reverted AppKit implementation.
- `Tests/Unit` covers ordering, editing, and persistence; `Tests/Support` holds shared test helpers and fixtures.

## Build, Test, and Development Commands
- `xed .` launches the project in Xcode.
- `xcodegen generate` regenerates `Listless.xcodeproj` from `project.yml`.
- `xcodebuild -scheme "Listless macOS" -destination 'platform=macOS' build` builds the native macOS app.
- `xcodebuild -scheme "Listless iOS" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build` builds the iOS app.
- `xcodebuild test -scheme "Listless iOS" -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'` runs unit + UI tests.
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
- Archives with signing, then exports an IPA with manual signing (`iPhone Distribution` cert, `Listless iOS Distribution` profile).

### macOS
- Run `Scripts/publish-macos.sh` from the repo root.
- Archives with signing, then exports a `.pkg` with manual signing (`3rd Party Mac Developer Application` + `3rd Party Mac Developer Installer` certs, `Listless macOS Distribution` profile).

## Build Number
- `CFBundleVersion` in both Info.plist files uses `$(CURRENT_PROJECT_VERSION)`, sourced from `Generated/BuildNumber.xcconfig`.
- Each scheme has a build pre-action that runs `git log`/`git rev-list` to compute `YEAR.COMMIT_COUNT` and writes it to the xcconfig before the build starts.
- Scheme pre-actions are not subject to `ENABLE_USER_SCRIPT_SANDBOXING`, which is why this lives in the scheme rather than a build phase script.
- `Generated/BuildNumber.xcconfig` is gitignored; the scheme pre-action creates it before every build.

## Coding Style & Naming Conventions
- Use SwiftUI + Observation (`@Observable`), indent four spaces, and prefer trailing commas in builders.
- Models are nouns (`TaskItem`), views end with `View`, and services end with `Service`; keep async methods verb-first (`syncTasks()`).
- Centralize state in `@Observable TaskStore` that wraps Core Data operations; mutations flow through intent methods like `complete(taskID:)`.
- `TaskStore.createTask(title:atBeginning:)` accepts an `atBeginning` flag (default `false`); when `true` assigns `minSortOrder - 1000` to prepend the task before all existing active tasks. `createTask` does **not** save — callers must call `store.save()` explicitly when they want to persist. This keeps empty placeholder tasks (from background tap or Return) in-memory only until the user types, avoiding iCloud sync of transient objects.
- Completed tasks display below active ones; never reorder or edit them in-place.
- For selection state in ForEach contexts, use computed Bool values + callbacks rather than passing @Binding to children (avoids SwiftUI update issues).
- The codebase uses "task" internally (e.g. `TaskItem`, `TaskStore`, `deleteTask`) but user-facing text (labels, toast messages, menu items) should use "item" instead.

## Sync & Data Guidelines
- Core Data with `NSPersistentCloudKitContainer` handles persistence and iCloud sync; configured in `PersistenceController` within `Listless/Sync`.
- `TaskItem` is an `NSManagedObject` subclass with auto-updating `updatedAt` timestamp via `willSave()`.
- CloudKit container identifier is `iCloud.net.inqk.listless`; entitlements are defined in `project.yml` and generated by XcodeGen.
- Keep CloudKit configuration and Core Data setup inside `Listless/Sync`; exposing raw Core Data contexts elsewhere is discouraged.
- `KeyValueSyncBridge` (`Listless/Sync/KeyValueSyncBridge.swift`) bridges `@AppStorage` keys to `NSUbiquitousKeyValueStore` for iCloud sync of user preferences. Currently syncs `"headingText"` (the customisable list title). On startup it pulls cloud values into `UserDefaults`; bidirectional observation keeps the two stores in sync with an `isSyncing` flag to prevent feedback loops. To sync additional preferences, add the key to the `keys` set in `ListlessiOSApp.init()`.
- When adding fields to the Core Data model, update `Listless.xcdatamodeld`, add migration mappings if needed, and document changes in `Docs/Schema.md`.

## Testing Guidelines
- Use Swift Testing framework with `@Test` macro and `#expect` assertions.
- Organize tests into `@Suite` groupings with descriptive names.
- Use natural function names that describe what's being tested (no `test` prefix required).
- Leverage parameterized tests with `@Test(arguments: [...])` for testing multiple scenarios.
- Maintain ≥80% coverage for `TaskStore` and Core Data operations, especially reordering edge cases and merge conflict resolution.
- UI tests must verify keyboard entry flows: pressing Return creates a task then focuses the new empty row; tapping whitespace also starts entry.
- Use `PersistenceController(inMemory: true)` for isolated test environments with Core Data.

## macOS Implementation: SwiftUI vs AppKit
- **Current implementation**: macOS uses SwiftUI (same as iOS)
- **AppKit alternative**: A complete AppKit implementation exists in `ListlessMac/AppKit/` but is excluded from builds
  - Attempted migration in Feb 2026 for better drag-and-drop control
  - Reverted due to state management complexity, focus issues, and selection bugs
  - SwiftUI's declarative patterns proved more maintainable for this app
- **Switching to AppKit** (if needed): Update `project.yml` to exclude SwiftUI views and include `ListlessMac/AppKit/`, then run `xcodegen generate`

## Menu Customisation (both platforms)
- **Do not use SwiftUI's `Commands` API** — broken on macOS 15 (dividers don't render, `CommandGroup(replacing:)` causes Window menu jitter) and on iPadOS (arrow key glyphs render as "?", `@FocusedValue` propagation fails when a UIKit view is first responder).
- **Both platforms use native menu APIs** with a shared coordinator pattern: action closures + enabled-state booleans updated by `TaskListView.updateMenuCoordinator()`.
- **Adding a new key binding** requires four touch points per platform: (1) coordinator — add action closure + enabled flag, (2) selector/action protocol — add the `@objc` method, (3) menu definition — register the key command in the right menu, (4) `updateMenuCoordinator()` — wire up the action and enabled state.

### macOS
- **Menus are fully AppKit-owned** in `AppDelegate.installMainMenu()` (`ListlessMac/ListlessMacApp.swift`), assigned directly via `NSApp.mainMenu`.
- **No runtime menu patching**: do not use `NSMenu.didAddItemNotification`/tag-guard patch logic for command setup in the current architecture.
- **`MenuCoordinator`** (`ListlessMac/Helpers/AppCommands.swift`) bridges SwiftUI state to AppKit. Enabled state is surfaced via `NSMenuItemValidation.validateMenuItem` on `AppDelegate`.
- **Command shortcuts are canonical in AppKit menus** (e.g. New Item, Move Up/Down, Mark Completed, Delete). Avoid duplicating those command shortcuts in `TaskListView.keyboardNavigation(...)`.
- **Selector style**: prefer typed `#selector(...)` where available; use `MenuSelectors` constants for string-based selectors that lack typed Swift symbols.
- **Window menu**: keep explicit baseline items in `installMainMenu()` and let `NSApp.windowsMenu` provide system-managed dynamic window list behavior.

### iOS (iPad)
- **Menus use UIKit's `buildMenu(with:)`** in `IOSAppDelegate` (`ListlessiOS/ListlessiOSApp.swift`), inserting `UIKeyCommand` items into standard `.file` and `.edit` menus so the iPad keyboard shortcut overlay groups them correctly.
- **`IOSMenuCoordinator`** (`ListlessiOS/Helpers/AppCommands.swift`) bridges SwiftUI state to UIKit. `IOSMenuActions` protocol declares `@objc` action selectors; `KeyCaptureView` (the first responder in `KeyCommandBridge`) conforms and dispatches to the coordinator.
- **Conditional availability**: `KeyCaptureView.canPerformAction(_:withSender:)` checks coordinator enabled flags; commands are greyed out in the overlay when conditions aren't met (e.g. Move Up disabled when selected task is first).
- **Plain (unmodified) key commands** (Up, Down, Space, Return, Delete) are still handled by `KeyCommandBridge`'s `keyCommands` property with `wantsPriorityOverSystemBehavior = true`. Command-modified shortcuts go through `buildMenu` → responder chain → `KeyCaptureView` action methods.

## iOS Implementation Notes
- **Platform-specific inits**: iOS and macOS `TaskRowView` have diverged (iOS takes `isDragging: Binding<Bool>`). When adding new parameters, update both `TaskRowView` inits and both `TaskListView` bodies.
- **Appearance override**: Use `UIWindow.overrideUserInterfaceStyle` in `ListlessiOSApp`, not `.preferredColorScheme()` (which doesn't properly revert to nil in sheets).
- **Focus guard for sheets**: The `onChange(of: focusedFieldBinding)` handler skips "reclaim focus to `.scrollView`" logic when a sheet is presented, preventing focus theft from sheet TextFields.
- **App icon in About screen**: Use `Image("AboutIcon")` from `Media.xcassets/AboutIcon.imageset` — `.appiconset` images can't be loaded via `Image()` in SwiftUI.
- **iOS color system**: `ListlessiOS/Helpers/AppColors.swift` defines `Color.outerBackground` and `Color.taskCard`. Adjust these two values to shift the palette.
- **Pull-to-create/clear**: Scroll gesture handling is in `.pullCreationGesture()` (`TaskListView+PullGestures.swift`); visual indicators are in `TaskListView+PullToCreate.swift` and `TaskListView+PullToClear.swift`. The macOS `body` omits all of these.

## SwiftUI Implementation Notes
- **TaskListView architecture**: Declared separately per platform (`ListlessiOS/Views/TaskListView.swift`, `ListlessMac/Views/TaskListView.swift`), both conforming to `TaskListViewProtocol`. State is grouped by concern: `fState` (focus), `iState` (interaction), `tState` (task/view-local). Shared logic lives in `TaskListView+Logic.swift` as an extension on `TaskListViewProtocol`. Because `private` is file-scoped, stored properties accessed from extensions must be `internal`. Platform-specific extensions that would return `EmptyView()` on the other platform are simply omitted.
- **Selection pattern**: Parent owns `@State var selectedTaskID`; children receive `isSelected: Bool` + `onSelect: () -> Void` callback (avoids SwiftUI ForEach update issues with @Binding).
- **Focus management**: Single `@FocusState` enum (`FocusField` in `TaskListTypes.swift`) with `.task(UUID)` and `.scrollView` cases. Never use multiple @FocusState variables for related focus. Keyboard handlers return `.ignored` when wrong focus state.
  - **Pending focus**: Set both `pendingFocus` and `focusedField` in `createNewTask()`. Do NOT resolve in `.onAppear` (race conditions). Clear `pendingFocus` in `startEditing()`. Guard `deleteIfEmpty()` against `pendingFocus` matches.
- **Text editing**: iOS uses `TappableTextField` (UIViewRepresentable wrapping `UITextView`); macOS uses `ClickableTextField` (NSViewRepresentable wrapping `NSTextField`). Both use delegate/coordinator patterns to bridge to SwiftUI. Key gotcha: `onEditingChanged` callbacks from UIKit may arrive during a SwiftUI update pass — defer via `DispatchQueue.main.async`.
- **Drag-and-drop**: Both platforms maintain `visualOrder` during drag and commit via `store.moveTask()` on release. macOS uses `onDrag` + `dropDestination`; iOS uses `LongPressGesture.sequenced(before: DragGesture)` via `.simultaneousGesture()`.
- **Keyboard navigation**: macOS uses dictionary-based keybindings in `KeyboardNavigationModifier.swift`. iOS uses `KeyCommandBridge` (UIViewRepresentable) because iPadOS `@FocusState` silently fails with hardware keyboards — the iOS `body` does **not** use `.focusable()`, `.focused(equals: .scrollView)`, or `.keyboardNavigation()`.
- Avoid `Spacer` inside `ScrollView` (causes unwanted scrollbar).
- **Escape hatches** (`GeometryReader`, `PreferenceKey`, `UIViewRepresentable`/`NSViewRepresentable`): only after exhausting SwiftUI-native alternatives (`.frame`, `.overlay`, `.background`, `alignmentGuide`).

## Commit & Pull Request Guidelines
- Do not create commits; the user handles version control.
- PR descriptions should summarize scope, list test commands, link issues, and attach screenshots or screen recordings for UI changes.
- Call out Core Data model or CloudKit schema updates explicitly and describe any expected migration impact.
