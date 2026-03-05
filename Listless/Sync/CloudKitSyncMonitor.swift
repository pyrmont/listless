import CoreData
import Foundation
import os

struct SyncDiagnosticEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let message: String
}

@MainActor
final class CloudKitSyncMonitor: ObservableObject {
    @Published private(set) var transientErrorMessage: String?
    @Published private(set) var lastSuccessfulSyncDate: Date?
    @Published private(set) var lastCloudKitErrorDomain: String?
    @Published private(set) var lastCloudKitErrorCode: Int?
    @Published private(set) var lastCloudKitErrorDescription: String?
    @Published private(set) var recentDiagnostics: [SyncDiagnosticEntry] = []

    private var monitoringTask: Task<Void, Never>?
    private var deferredTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "net.inqk.listless", category: "CloudKitSync")
    private let maxDiagnosticEntries = 80

    var hasDiagnosticsIssue: Bool {
        transientErrorMessage != nil || lastCloudKitErrorDescription != nil
    }

    deinit {
        monitoringTask?.cancel()
        deferredTask?.cancel()
    }

    func startMonitoring(container: NSPersistentCloudKitContainer) {
        guard monitoringTask == nil else { return }
        logger.info("Starting CloudKit event monitoring")
        appendDiagnostic(level: "info", "Starting CloudKit event monitoring")

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
                    self.logger.error("Received CloudKit eventChangedNotification without event payload")
                    self.appendDiagnostic(
                        level: "error",
                        "Received eventChangedNotification without event payload"
                    )
                    continue
                }

                let eventDescription =
                    "CloudKit event: type=\(self.eventTypeName(event.type)) endDatePresent=\(event.endDate != nil)"
                self.logger.debug("\(eventDescription, privacy: .public)")
                self.appendDiagnostic(level: "debug", eventDescription)

                if let error = event.error {
                    self.logCloudKitError(error)
                    self.handle(issue: CloudKitErrorClassifier.classify(error))
                } else if self.isSuccessfulSyncCompletion(event) {
                    self.deferredTask?.cancel()
                    self.deferredTask = nil
                    self.transientErrorMessage = nil
                    self.lastSuccessfulSyncDate = event.endDate ?? Date()
                    let successDescription = "CloudKit sync succeeded: type=\(self.eventTypeName(event.type))"
                    self.logger.info("\(successDescription, privacy: .public)")
                    self.appendDiagnostic(level: "info", successDescription)
                }
            }
        }
    }

    func ingest(error: Error) {
        handle(issue: CloudKitErrorClassifier.classify(error))
    }

    private func handle(issue: SyncIssue) {
        switch issue {
        case .transient(let message):
            logger.warning("Transient sync issue: \(message, privacy: .public)")
            appendDiagnostic(level: "warning", "Transient sync issue: \(message)")
            showTransient(message)

        case .deferred(let message):
            logger.warning("Deferred sync issue scheduled: \(message, privacy: .public)")
            appendDiagnostic(level: "warning", "Deferred sync issue scheduled: \(message)")
            guard deferredTask == nil else { return }
            deferredTask = Task {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                showTransient(message)
                self.logger.warning("Deferred sync issue surfaced: \(message, privacy: .public)")
                self.appendDiagnostic(level: "warning", "Deferred sync issue surfaced: \(message)")
            }
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

    private func eventTypeName(_ type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup:
            return "setup"
        case .import:
            return "import"
        case .export:
            return "export"
        @unknown default:
            return "unknown"
        }
    }

    private func logCloudKitError(_ error: Error) {
        let nsError = error as NSError
        lastCloudKitErrorDomain = nsError.domain
        lastCloudKitErrorCode = nsError.code
        lastCloudKitErrorDescription = nsError.localizedDescription
        let message =
            "CloudKit event error: domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) userInfo=\(String(describing: nsError.userInfo))"
        logger.error(
            """
            \(message, privacy: .public)
            """
        )
        appendDiagnostic(level: "error", message)
    }

    private func appendDiagnostic(level: String, _ message: String) {
        recentDiagnostics.append(SyncDiagnosticEntry(timestamp: Date(), level: level, message: message))
        if recentDiagnostics.count > maxDiagnosticEntries {
            recentDiagnostics.removeFirst(recentDiagnostics.count - maxDiagnosticEntries)
        }
    }
}
