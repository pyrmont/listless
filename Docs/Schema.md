# Listless Schema Notes

## TaskItem
- `id: UUID` — stable primary key generated at creation; used as the Boutique `ItemIdentifier`.
- `title: String` — UTF-8 text up to 2,048 characters; may be empty or contain only whitespace to represent placeholder rows. Preserve user-entered blank lines.
- `isCompleted: Bool` — toggled freely; set `false` when unmarking a task so previously archived items can return to the active bucket.
- `createdAt: Date` — timestamp used for deterministic ordering when indexes match.
- `updatedAt: Date` — refreshed on every mutation to aid conflict resolution between local cache and iCloud.

## Storage & Sync
- Boutique `Store<TaskItem>` configured with `StorageEngine.cloudKit(appGroup: "net.inqk.listless")` keeps data synced across macOS, iOS, and iPadOS.
- Listless uses a single list collection; avoid multiple stores to prevent divergence.
- Keep serialization inside `Listless/Sync`; expose helpers that convert between `TaskItem` and CloudKit records if custom fields become necessary.
- When adding fields, document them in this file and note whether migrations are required so contributors can coordinate schema bumps.
