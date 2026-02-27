import CloudKit
import Foundation
import Testing

@testable import Listless_iOS

@Suite("CloudKitErrorClassifier")
struct CloudKitErrorClassifierTests {

    // MARK: - Transient Errors

    @Test(
        "Network and server errors are transient",
        arguments: [
            CKError.Code.networkUnavailable,
            CKError.Code.networkFailure,
            CKError.Code.serviceUnavailable,
            CKError.Code.requestRateLimited,
            CKError.Code.zoneBusy,
            CKError.Code.serverResponseLost,
            CKError.Code.operationCancelled,
        ]
    )
    func transientErrors(code: CKError.Code) {
        let error = CKError(code)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("retry"))
    }

    // MARK: - Deferred Errors

    @Test(
        "First-launch errors are deferred",
        arguments: [
            CKError.Code.accountTemporarilyUnavailable,
            CKError.Code.zoneNotFound,
            CKError.Code.userDeletedZone,
        ]
    )
    func deferredErrors(code: CKError.Code) {
        let error = CKError(code)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .deferred(let message) = issue else {
            Issue.record("Expected .deferred, got \(issue)")
            return
        }
        #expect(message.contains("retry"))
    }

    // MARK: - Actionable Alerts

    @Test("Not authenticated requires sign-in")
    func notAuthenticated() {
        let error = CKError(.notAuthenticated)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .alert(let alert) = issue else {
            Issue.record("Expected .alert, got \(issue)")
            return
        }
        #expect(alert.title.contains("Sign-In"))
        #expect(alert.action == .openSettings)
    }

    @Test("Quota exceeded shows storage full")
    func quotaExceeded() {
        let error = CKError(.quotaExceeded)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .alert(let alert) = issue else {
            Issue.record("Expected .alert, got \(issue)")
            return
        }
        #expect(alert.title.contains("Storage Full"))
        #expect(alert.action == .openSettings)
    }

    @Test(
        "Permission errors show unavailable",
        arguments: [
            CKError.Code.permissionFailure,
            CKError.Code.badContainer,
            CKError.Code.missingEntitlement,
        ]
    )
    func permissionErrors(code: CKError.Code) {
        let error = CKError(code)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .alert(let alert) = issue else {
            Issue.record("Expected .alert, got \(issue)")
            return
        }
        #expect(alert.title.contains("Unavailable"))
        #expect(alert.action == .openSettings)
    }

    // MARK: - Default / Unknown CKError

    @Test("Unknown CKError code is deferred")
    func unknownCKError() {
        let error = CKError(.internalError)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .deferred(let message) = issue else {
            Issue.record("Expected .deferred, got \(issue)")
            return
        }
        #expect(message.contains("retry"))
    }

    // MARK: - Non-CloudKit Errors

    @Test("Core Data error shows save failure alert")
    func coreDataError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 1570, userInfo: nil)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .alert(let alert) = issue else {
            Issue.record("Expected .alert, got \(issue)")
            return
        }
        #expect(alert.title == "Unable to Save Changes")
    }

    @Test("Unknown domain error shows generic sync error")
    func unknownDomainError() {
        let error = NSError(domain: "com.example.unknown", code: 42, userInfo: nil)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .alert(let alert) = issue else {
            Issue.record("Expected .alert, got \(issue)")
            return
        }
        #expect(alert.title == "Sync Error")
    }
}
