import CloudKit
import Foundation

enum SyncAlertAction {
    case openSettings
}

struct SyncAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: SyncAlertAction?
}

enum SyncIssue {
    case transient(message: String)
    case alert(SyncAlertItem)
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

        if nsError.domain == NSCocoaErrorDomain {
            return .alert(
                SyncAlertItem(
                    title: "Unable to Save Changes",
                    message: "Your changes are still local, but syncing encountered an issue. Please try again.",
                    action: nil
                ))
        }

        return .alert(
            SyncAlertItem(
                title: "Sync Error",
                message: rootError.localizedDescription,
                action: nil
            ))
    }

    private static func classifyCloudKit(code: CKError.Code) -> SyncIssue {
        switch code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
            .zoneBusy, .serverResponseLost, .operationCancelled:
            return .transient(message: "Saved locally. iCloud sync will retry automatically.")

        case .notAuthenticated:
            return .alert(
                SyncAlertItem(
                    title: "iCloud Sign-In Required",
                    message:
                        "Sign in to iCloud in Settings to continue syncing your tasks across devices.",
                    action: .openSettings
                ))

        case .quotaExceeded:
            return .alert(
                SyncAlertItem(
                    title: "iCloud Storage Full",
                    message:
                        "Free up iCloud storage or upgrade your plan to continue syncing.",
                    action: .openSettings
                ))

        case .permissionFailure, .badContainer, .missingEntitlement:
            return .alert(
                SyncAlertItem(
                    title: "iCloud Sync Unavailable",
                    message:
                        "This device currently cannot access iCloud for syncing. Check iCloud settings and try again.",
                    action: .openSettings
                ))

        default:
            return .alert(
                SyncAlertItem(
                    title: "Sync Error",
                    message:
                        "Changes are saved locally, but iCloud sync failed. The app will try again automatically.",
                    action: nil
                ))
        }
    }

    private static func unwrap(_ error: Error) -> Error {
        if let storeError = error as? TaskStoreError {
            switch storeError {
            case .fetchFailed(let wrappedError), .saveFailed(let wrappedError):
                return wrappedError
            }
        }
        return error
    }
}
