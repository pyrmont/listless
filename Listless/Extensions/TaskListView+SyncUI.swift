import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension TaskListViewProtocol {
    @ViewBuilder
    var syncErrorBanner: some View {
        if let message = syncMonitor.transientErrorMessage {
            HStack(spacing: 8) {
                Image(systemName: "icloud.slash")
                    .imageScale(.small)
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    func openSystemSettings() {
        #if os(iOS)
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        #elseif os(macOS)
            if let settingsURL = URL(string: "x-apple.systempreferences:") {
                NSWorkspace.shared.open(settingsURL)
            }
        #endif
    }
}
