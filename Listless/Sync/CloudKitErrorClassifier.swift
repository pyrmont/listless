import CloudKit
import Foundation

enum SyncIssue {
    case transient(message: String)
    case deferred(message: String)
}

enum CloudKitErrorClassifier {
    static func classify(_ error: Error) -> SyncIssue {
        let rootError = unwrap(error)
        let nsError = rootError as NSError

        if nsError.domain == CKError.errorDomain,
            let ckCode = CKError.Code(rawValue: nsError.code)
        {
            return classifyCloudKit(code: ckCode)
        }

        return .transient(message: "Saved locally. iCloud sync will retry automatically.")
    }

    private static func classifyCloudKit(code: CKError.Code) -> SyncIssue {
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
            .zoneBusy, .serverResponseLost, .operationCancelled:
            return .transient(message: "Saved locally. iCloud sync will retry automatically.")

        case .notAuthenticated:
            return .transient(message: "Sign in to iCloud to sync across devices.")

        case .quotaExceeded:
            return .transient(message: "iCloud storage full. Free up space to continue syncing.")

        case .permissionFailure, .badContainer, .missingEntitlement:
            return .transient(message: "iCloud sync unavailable. Check iCloud settings.")

        case .accountTemporarilyUnavailable, .zoneNotFound, .userDeletedZone:
            return .deferred(message: "Saved locally. iCloud sync will retry automatically.")

        default:
            return .deferred(message: "Saved locally. iCloud sync will retry automatically.")
        }
    }

    private static func unwrap(_ error: Error) -> Error {
        if let storeError = error as? ItemStoreError {
            switch storeError {
            case .fetchFailed(let wrappedError), .saveFailed(let wrappedError):
                return wrappedError
            }
        }
        return error
    }
}
