import CloudKit
import Foundation
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

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

    // MARK: - Transient Actionable Errors

    @Test("Not authenticated is transient with sign-in message")
    func notAuthenticated() {
        let error = CKError(.notAuthenticated)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("Sign in"))
    }

    @Test("Quota exceeded is transient with storage message")
    func quotaExceeded() {
        let error = CKError(.quotaExceeded)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("storage full"))
    }

    @Test(
        "Permission errors are transient with unavailable message",
        arguments: [
            CKError.Code.permissionFailure,
            CKError.Code.badContainer,
            CKError.Code.missingEntitlement,
        ]
    )
    func permissionErrors(code: CKError.Code) {
        let error = CKError(code)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("unavailable"))
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

    @Test("Core Data error is transient")
    func coreDataError() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 1570, userInfo: nil)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("retry"))
    }

    @Test("Unknown domain error is transient")
    func unknownDomainError() {
        let error = NSError(domain: "com.example.unknown", code: 42, userInfo: nil)
        let issue = CloudKitErrorClassifier.classify(error)

        guard case .transient(let message) = issue else {
            Issue.record("Expected .transient, got \(issue)")
            return
        }
        #expect(message.contains("retry"))
    }
}
