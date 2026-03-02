# Repository Guidelines

## Project Structure & Module Organization
- `Listless.xcodeproj` coordinates two app targets: "Listless iOS" (iPhone/iPad) and "Listless macOS" (native Mac), both sharing code from the `Listless/` directory.
- `project.yml` defines the Xcode project structure for XcodeGen; run `xcodegen generate` to regenerate the project after modifying it.
- `Listless/Models` owns `TaskItem` (NSManagedObject), `TaskStore` (@Observable wrapper), and Core Data model definitions; keep CloudKit configuration inside `Listless/Sync`.
- `Listless/Extensions` holds extensions on shared types; `TaskListView+Logic.swift` and `TaskListView+SyncUI.swift` are extensions on `TaskListViewProtocol` (not the concrete struct) so SourceKit can resolve them unambiguously across both targets.
- `Listless/Helpers` holds shared non-view supporting code (`AccentColor`, `KeyboardNavigationModifier`, `TaskListTypes`, `TaskListViewProtocol`). `TaskListTypes.swift` defines the `FocusField` and `DragState` enums as top-level types (shared by both platform `TaskListView` structs). `TaskListViewProtocol.swift` defines the `@MainActor TaskListViewProtocol` that both structs conform to, declaring the shared property contract (`tasks`, `store`, `syncMonitor`, `managedObjectContext`, `focusedField`, `selectedTaskID`, `pendingFocus`, `dragState`, `didStartDrag()`).
- `ListlessiOS/` contains the iOS app entry point, organised into three subdirectories:
  - `Views/` — iOS-specific view components (`TaskListView`, `TaskRowView`, `PullToCreate`).
  - `Helpers/` — gesture recognizers, UIKit representables, color definitions, and platform-shim view modifiers (`TappableTextField`, `TaskRowSwipeGesture`, `TaskRowDragGesture`, `AppColors`, `HoverCursorModifier`, etc.).
  - `Extensions/` — platform-specific extensions on shared types (`TaskListView+NavigationHeader`, `TaskListView+Toolbar`, `TaskListView+PullToCreate`, `TaskListView+Drag`).
- `ListlessMac/` contains the macOS app entry point with the same three-subdirectory structure as `ListlessiOS/` (`Views/` includes `TaskListView`); an excluded `AppKit/` subdirectory holds the reverted AppKit implementation.
- `Tests/Unit` covers ordering, editing, and persistence, while `Tests/UI` handles simulator automation using launch arguments defined in `Tests/Support` fixtures.

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
- Use SwiftUI + Combine, indent four spaces, and prefer trailing commas in builders.
- Models are nouns (`TaskItem`), views end with `View`, and services end with `Service`; keep async methods verb-first (`syncTasks()`).
- Centralize state in `@Observable TaskStore` that wraps Core Data operations; mutations flow through intent methods like `complete(taskID:)`.
- `TaskStore.createTask(title:atBeginning:)` accepts an `atBeginning` flag (default `false`); when `true` assigns `minSortOrder - 1000` to prepend the task before all existing active tasks.
- Completed tasks display below active ones; never reorder or edit them in-place.
- For selection state in ForEach contexts, use computed Bool values + callbacks rather than passing @Binding to children (avoids SwiftUI update issues).

## Sync & Data Guidelines
- Core Data with `NSPersistentCloudKitContainer` handles persistence and iCloud sync; configured in `PersistenceController` within `Listless/Sync`.
- `TaskItem` is an `NSManagedObject` subclass with auto-updating `updatedAt` timestamp via `willSave()`.
- CloudKit container identifier is `iCloud.net.inqk.listless`; entitlements are defined in `project.yml` and generated by XcodeGen.
- Keep CloudKit configuration and Core Data setup inside `Listless/Sync`; exposing raw Core Data contexts elsewhere is discouraged.
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

## macOS Menu Customisation
- **Do not use SwiftUI's `Commands` API** — broken on macOS 15: dividers don't render and `CommandGroup(replacing:)` causes Window menu jitter.
- **Menus are fully AppKit-owned** in `AppDelegate.installMainMenu()` (`ListlessMac/ListlessMacApp.swift`), assigned directly via `NSApp.mainMenu`.
- **No runtime menu patching**: do not use `NSMenu.didAddItemNotification`/tag-guard patch logic for command setup in the current architecture.
- **`MenuCoordinator`** (`ListlessMac/Helpers/AppCommands.swift`) bridges SwiftUI state to AppKit: action closures + enabled-state booleans updated by `TaskListView.updateMenuCoordinator()`. Enabled state is surfaced via `NSMenuItemValidation.validateMenuItem` on `AppDelegate`.
- **Command shortcuts are canonical in AppKit menus** (e.g. New Task, Move Up/Down, Mark Completed, Delete). Avoid duplicating those command shortcuts in `TaskListView.keyboardNavigation(...)`.
- **Selector style**: prefer typed `#selector(...)` where available; use `MenuSelectors` constants for string-based selectors that lack typed Swift symbols.
- **Window menu**: keep explicit baseline items in `installMainMenu()` and let `NSApp.windowsMenu` provide system-managed dynamic window list behavior.

## iOS Implementation Notes
- **Platform-specific inits**: `ListlessiOS/Views/TaskRowView.swift` and `ListlessMac/Views/TaskRowView.swift` have diverged — iOS takes `isDragging: Binding<Bool>` while macOS does not. This is fine because each platform has its own `TaskListView.swift` in its platform-specific `Views/` directory, so identical call-site signatures are not required. When adding new parameters, update both `TaskRowView` inits and both `TaskListView` bodies.
- **Swipe gesture**: Pure SwiftUI — `DragGesture(minimumDistance: 10, coordinateSpace: .local)` applied via `.simultaneousGesture()` for scroll coexistence. Direction discrimination happens in `handleDragChanged`: `abs(horizontalTranslation) > verticalTranslation + 10` must hold before any swipe offset is applied, so vertical scrolls pass through without activating the swipe. Haptic feedback uses `@State var hapticTrigger` toggled in `triggerAction` with a `.sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)` modifier on the ZStack.
  - `isDragging` is passed as `@Binding var isDragging: Bool` all the way from `TaskListView` (`@State var isDragging: Bool`, iOS-only, declared in `ListlessiOS/Views/TaskListView.swift`) through `TaskRowView` to `TaskRowSwipeGesture`. The `@Binding` drives both the `including: isDragging ? .none : .all` gesture mask (disables recognition entirely during drag reordering) and the `guard !isDragging` check inside `onChanged`.
  - `isActive` and `isEditing` were removed from the gesture interface — `isActive` was always `true` at the call site (the gesture is only applied to active task rows in the ForEach), and `isEditing` can never be true during an active swipe (you can't initiate a horizontal pan while the keyboard is up).
- **Incremental build**: iOS views are built in stages. The stub accepts the full interface; behaviour is filled in progressively. Keep the init signature in sync with macOS when adding parameters.
- **Title and navigation**: `ListlessiOSApp.swift` uses a plain `WindowGroup` with no `NavigationStack`. The navigation header title ("Tasks") is rendered as a SwiftUI `Text` inside the `ScrollView` via the `navigationHeader` computed property defined in `ListlessiOS/Extensions/TaskListView+NavigationHeader.swift`; the macOS `body` in `ListlessMac/Views/TaskListView.swift` simply omits the call, so no macOS stub is needed. A `.overlay(alignment: .top)` of `Color.outerBackground.opacity(0.9).ignoresSafeArea(edges: .top).frame(height: 0)` covers the status bar region so scroll content doesn't show under the clock and system icons.
- **iOS color system**: `ListlessiOS/Helpers/AppColors.swift` defines `Color.outerBackground` and `Color.taskCard` as adaptive `UIColor`-backed colors (warm gray/black outer; white/dark-gray card). Adjust these two values to shift the overall palette.
- **iOS card layout**: Active task rows use `UnevenRoundedRectangle` — square leading corners (cards extend flush to the left screen edge, no leading margin) and 14pt trailing corners. Completed rows have no card background and sit directly on `outerBackground`. VStack spacing (12pt) and padding (trailing + vertical) are set directly in `ListlessiOS/Views/TaskListView.swift`; the macOS `TaskListView.swift` uses 0 spacing and no padding.
- **Gradient accent bars**: Each active row has an 8pt `Rectangle` on the leading edge filled with `cachedAccentColor` — a gradient interpolated across HSB color stops (coral → magenta → purple-blue) based on `index`/`totalTasks`. Color is computed once on appear and recomputed via `onChange(of: "\(index)-\(totalTasks)")`. The same gradient is used as the swipe-right reveal color via the `completeColor` parameter on `taskSwipeGesture`. The color stops and interpolation logic are identical to the macOS version in `ListlessMac/Views/TaskRowView.swift`. The shared interpolation function lives in `Listless/Helpers/AccentColor.swift`.
- **iOS drag-and-drop**: Long-press (0.4s) begins a drag; the row stays in-place but receives `scaleEffect(1.03)` + shadow + elevated `zIndex` — no floating overlay or ghost spacer. Implemented with pure SwiftUI `LongPressGesture(minimumDuration: 0.4).sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))` via `.simultaneousGesture()`; `.scrollDisabled(draggedTaskID != nil)` prevents the ScrollView from stealing touches. `rowFrames: [UUID: CGRect]` tracks each row's global frame via `.onGeometryChange`; when the finger moves past 20% of the dragged row's height beyond its own edge the row swaps with its immediate neighbour (spring animation); `visualOrder: [UUID]?` holds the in-progress order. `commitIOSDrag()` calls `store.moveTask()` on release. The macOS `taskDragGesture` extension accepts the same parameters with no-op defaults to keep the shared call-site signature.
- **Pull-to-create**: Pulling down past the top of the scroll view (iOS only) creates a new task at the beginning of the active list. Implemented with `onScrollGeometryChange` (extracts `max(0, -(geo.contentOffset.y + geo.contentInsets.top))` as the pull distance — goes positive during rubber-band overscroll) and `onScrollPhaseChange` (triggers task creation when transitioning out of `.interacting`). A `sensoryFeedback` modifier with a `!old && new` condition fires haptic once when the 70pt threshold is first crossed. The visual indicator (`PullToCreateIndicator` in `ListlessiOS/Views/PullToCreate.swift`) grows in the VStack between `navigationHeader` and the first task row via the `pullToCreateIndicatorRow` extension property in `ListlessiOS/Extensions/TaskListView+PullToCreate.swift`. All of these — the scroll modifiers, `sensoryFeedback`, and `pullToCreateIndicatorRow` call — live directly in the iOS `body` in `ListlessiOS/Views/TaskListView.swift`; the macOS `body` omits them entirely so no macOS stub is needed. The header stays fixed during the pull gesture via `.offset(y: -pullOffset)` applied to the entire VStack — this counteracts the ScrollView's rubber-band displacement exactly, so the header appears stationary while the indicator grows beneath it; during normal scrolling the header scrolls with the list as usual.
  - **Indicator state**: `createIndicatorOffset` (separate from `pullOffset`) only updates while `isScrollInteracting` is true, so the indicator doesn't collapse during the rubber-band snapback after the user lifts their finger. `isCreateInsertionPending` latches to `true` on release when the threshold is met, keeping the indicator visible and pinned at `pullCreateThreshold` height until the new task actually appears. `activeTaskCountBeforeCreate` captures `activeTasks.count` immediately before calling `createNewTaskAtTop()`. An `onChange(of: activeTasks.count)` observer waits until `newCount > activeTaskCountBeforeCreate`, then clears both `isCreateInsertionPending` and `createIndicatorOffset` atomically with `disablesAnimations: true` — this removes the indicator in the same render pass that the ForEach inserts the new task row, eliminating the layout-shift blink that would otherwise occur. The `pullToCreateIndicatorRow` `@ViewBuilder` shows whenever `createIndicatorOffset > 0 || isCreateInsertionPending`.

## SwiftUI Implementation Notes
- **TaskListView architecture**: The struct is declared separately in `ListlessiOS/Views/TaskListView.swift` and `ListlessMac/Views/TaskListView.swift`, each with its own platform-specific `body`. Both conform to `TaskListViewProtocol` (defined in `Listless/Helpers/TaskListViewProtocol.swift`), which declares the shared property contract. Both group state by concern using `fState` (focus), `iState` (interaction), and `tState` (task/view-local), with compatibility computed properties preserving existing shared extension APIs during migration. All shared business logic — computed properties, task CRUD, focus management, keyboard navigation, drag state — lives in `Listless/Extensions/TaskListView+Logic.swift` as an extension on `TaskListViewProtocol` (not the concrete struct), so SourceKit resolves it unambiguously. Because `private` in Swift is file-scoped, stored properties accessed from the extension must be declared without the `private` modifier (i.e. `internal`). Platform-specific body helpers follow the same extension pattern already used for `platformToolbar` and `navigationHeader`; macOS extensions that would return `EmptyView()` are simply omitted — the macOS `body` just doesn't call those properties.
- **Selection pattern**: TaskListView owns `@State var selectedTaskID`, children receive `isSelected: Bool` + `onSelect: () -> Void` callback
  - Computed Bool pattern prevents SwiftUI ForEach update issues that occur when passing @Binding directly to children
- **Focus management**: Uses single `@FocusState` enum for unified focus management
  - `FocusField` enum (top-level, in `Listless/Helpers/TaskListTypes.swift`) with cases: `.task(UUID)` for TextFields, `.scrollView` for navigation mode
  - Single source of truth prevents coordination issues; never use multiple @FocusState variables for related focus
  - TextField auto-focuses on click (native), `onChange(of: focusedField)` triggers selection
  - Keyboard handlers return `.ignored` when wrong focus state to allow event propagation
  - **Pending focus resolution**: When creating a new task (e.g., Return on last task), use both `pendingFocus` and direct `focusedField` assignment
    - Set both `pendingFocus = .task(newTaskID)` AND `focusedField = .task(newTaskID)` in `createNewTask()`
    - Direct `focusedField` assignment: for `TappableTextField` (iOS) where `textFieldShouldReturn` returns `false` — `focusedField` never goes nil, so SwiftUI transfers first responder atomically in the same render pass
    - `pendingFocus` fallback: for the background-tap flow where `focusedField` is subsequently forced to nil; `onChange(of: focusedField)` resolves it when nil is detected
    - Do NOT try to resolve in `.onAppear` (timing-dependent, causes race conditions)
    - Clear `pendingFocus = nil` in `startEditing()` once the field is live, preventing stale resolution
    - Guard `deleteIfEmpty()` against deleting tasks that match `pendingFocus`
- **Background tap handling**: ScrollView has `onTapGesture` + `contentShape(Rectangle())` to capture whitespace taps; macOS rows use a plain `onTapGesture`; iOS rows use `.onTapGesture` — neither uses `highPriorityGesture`
- **Text display/editing (iOS)**: Uses always-present `TappableTextField` (UIViewRepresentable wrapping `UITextView`)
  - `UITextView` with `isScrollEnabled = false` and `sizeThatFits` expands vertically to wrap text across multiple lines; `textContainerInset = .zero` and `lineFragmentPadding = 0` remove its default internal padding
  - `UITextViewDelegate` callbacks (`textViewDidBeginEditing`, `textViewDidEndEditing`) drive `onStartEdit`/`onEndEdit` directly — no `onChange(of: focusedField)` needed in `TaskRowView`
  - Return key intercepted in `textView(_:shouldChangeTextIn:replacementText:)` — returns `false` for `"\n"` to block newline insertion while calling `onEditingChanged(false, true)`; UIKit never auto-resigns, keeping keyboard visible during first-responder transfer to new rows
  - `onEditingChanged` callbacks from UIKit may arrive during a SwiftUI update pass; if they need to mutate SwiftUI state, defer via `DispatchQueue.main.async` to avoid "Modifying state during view update" warnings
  - Applied with `.focused($focusedField, equals: .task(taskID))` — SwiftUI's focus machinery handles `becomeFirstResponder()`/`resignFirstResponder()` automatically
  - `returnKeyPressed` flag prevents double-calling `onEditingChanged` when `textViewDidEndEditing` fires after the first-responder transfer
  - Placeholder "Enter task" implemented as a `UILabel` subview (UITextView has no native placeholder property); shown/hidden based on text emptiness
- **Text display/editing (macOS)**: Uses always-present `ClickableTextField` (NSViewRepresentable)
  - Custom `ClickableNSTextField` subclass overrides `becomeFirstResponder()` to detect clicks
  - Coordinator bridges AppKit → SwiftUI via two complementary paths: `becomeFirstResponder` → `onEditingChanged(true)` for immediate row highlighting on click; `controlTextDidBeginEditing` → `onEditingChanged(true)` for programmatic focus (e.g. after task creation) where the mouse-click check doesn't fire. A `hasNotifiedEditingStarted` flag prevents double-notification when both paths trigger.
  - Dynamic sizing via `sizeThatFits()`: compact when not editing, full width when editing (supports 1-5 lines wrapping)
  - Return key resigns first responder (prevents newline insertion), triggering `controlTextDidEndEditing` → `onEditingChanged(false)`
  - Unified behavior: Return and focus loss do the same thing (no separate onSubmit callback)
  - Coordinator pattern: holds @Binding and closures, updates SwiftUI state from AppKit delegate methods
- **Drag-and-drop reordering**: Both platforms maintain `visualOrder` during drag for live preview and commit to Core Data via `store.moveTask()` on release; keyboard navigation uses `displayActiveTasks` (visual order during drag, data order otherwise)
  - **macOS**: `onDrag` + `dropDestination` with `isTargeted` callbacks; three-zone overlay on each row (1/6 top, 2/3 middle, 1/6 bottom) using `.layoutPriority()` for proportional sizing; top zone always inserts before, bottom always after, middle uses smart direction logic; VStack catch-all `dropDestination` handles the actual drop; ScrollView-level `.onDrop` catch-all clears drag state when a drag is cancelled without a successful drop; 1×1 transparent drag preview; visual lift (scale + shadow + zIndex) triggers on hold (0.4s) via `liftedTaskID` before the drag session begins — `LongPressGesture` in `TaskRowDragGesture` fires `onLift`, an `NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp)` monitor clears the lift on release without drag; once `.onDrag` fires, `draggedTaskID` takes over and `liftedTaskID` is cleared; `isRowLifted()` combines both states for the visual modifiers; note that `leftMouseUp` does not fire during system drag sessions (macOS enters a modal event loop), so cancelled-drag cleanup relies on the ScrollView catch-all `.onDrop`; all of this lives directly in the macOS `body` in `ListlessMac/Views/TaskListView.swift` and `ListlessMac/Helpers/TaskRowDragGesture.swift`
  - **iOS**: `LongPressGesture(minimumDuration: 0.4).sequenced(before: DragGesture(...))` via `.simultaneousGesture()`; dragged row stays in-place with scale/shadow/zIndex lift (no overlay or ghost spacer); row frames tracked via `.onGeometryChange` (global coords); neighbour-swap when finger crosses 20% of row height past its own edge; `visualOrder` updated with spring animation; `handleIOSDragChanged` and `commitIOSDrag` live in `ListlessiOS/Extensions/TaskListView+Drag.swift`; `didStartDrag()` (sets `isDragging`, triggers haptic) is defined on the iOS struct in `ListlessiOS/Views/TaskListView.swift` with an empty no-op counterpart on the macOS struct
- **Keyboard navigation system**: Dictionary-based keybindings in `Listless/Helpers/KeyboardNavigationModifier.swift`
  - `ShortcutKey` struct combines `KeyEquivalent` + `EventModifiers` for flexible shortcuts
  - Manual Hashable conformance required (EventModifiers doesn't auto-conform)
  - Key normalization: backspace character `\u{7F}` → `.delete` for consistent matching
  - Modifier normalization: strips `.function` and `.numericPad` (system modifiers that come with arrow keys)
  - Only user-intentional modifiers (.command, .shift, .option, .control) are matched
  - Supports modifier-based shortcuts like `ShortcutKey(key: "n", modifiers: .command)` for future ⌘N
- Avoid `Spacer` inside `ScrollView` (causes unwanted scrollbar when content fits viewport).
- **Escape hatches** (`GeometryReader`, `PreferenceKey` size reporting, `UIViewRepresentable`/`NSViewRepresentable`): only reach for these after exhausting SwiftUI-native alternatives. They add complexity, can cause layout loops, and make state flow harder to follow. If you find yourself about to use one, first try `.frame`, `.overlay`, `.background`, `alignmentGuide`, or a different view decomposition.

## Commit & Pull Request Guidelines
- Do not create commits; the user handles version control.
- PR descriptions should summarize scope, list test commands, link issues, and attach screenshots or screen recordings for UI changes.
- Call out Core Data model or CloudKit schema updates explicitly and describe any expected migration impact.
