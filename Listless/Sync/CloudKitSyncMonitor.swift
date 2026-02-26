import CoreData
import Foundation

@MainActor
final class CloudKitSyncMonitor: ObservableObject {
    @Published private(set) var transientErrorMessage: String?
    @Published var actionableAlert: SyncAlertItem?

    private var monitoringTask: Task<Void, Never>?
    private var deferredTask: Task<Void, Never>?

    deinit {
        monitoringTask?.cancel()
        deferredTask?.cancel()
    }

    func startMonitoring(container: NSPersistentCloudKitContainer) {
        guard monitoringTask == nil else { return }

        monitoringTask = Task { [weak self] in
            guard let self else { return }

            for await notification in NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container
            ) {
                guard
                    let event =
                        notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event
                else {
                    continue
                }

                if let error = event.error {
                    self.handle(issue: CloudKitErrorClassifier.classify(error))
                } else if self.isSuccessfulSyncCompletion(event) {
                    self.deferredTask?.cancel()
                    self.deferredTask = nil
                    self.transientErrorMessage = nil
                }
            }
        }
    }

    func clearActionableAlert() {
        actionableAlert = nil
    }

    func ingest(error: Error) {
        handle(issue: CloudKitErrorClassifier.classify(error))
    }

    private func handle(issue: SyncIssue) {
        switch issue {
        case .transient(let message):
            showTransient(message)

        case .deferred(let message):
            guard deferredTask == nil else { return }
            deferredTask = Task {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                showTransient(message)
            }

        case .alert(let alert):
            actionableAlert = alert
        }
    }

    private func showTransient(_ message: String) {
        transientErrorMessage = message
    }

    private func isSuccessfulSyncCompletion(_ event: NSPersistentCloudKitContainer.Event) -> Bool {
        guard event.endDate != nil else { return false }

        switch event.type {
        case .import, .export:
            return true
        case .setup:
            return false
        @unknown default:
            return false
        }
    }
}
