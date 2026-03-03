import SwiftUI

struct SyncDiagnosticsView: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        List {
            Section("Status") {
                row("Transient Banner", syncMonitor.transientErrorMessage ?? "None")
                row("Last Error Domain", syncMonitor.lastCloudKitErrorDomain ?? "None")
                row(
                    "Last Error Code",
                    syncMonitor.lastCloudKitErrorCode.map(String.init) ?? "None"
                )
                row("Last Error Description", syncMonitor.lastCloudKitErrorDescription ?? "None")
                row(
                    "Last Success",
                    syncMonitor.lastSuccessfulSyncDate.map(Self.timestampFormatter.string(from:))
                        ?? "None"
                )
            }

            Section("Recent Events") {
                if syncMonitor.recentDiagnostics.isEmpty {
                    Text("No events captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncMonitor.recentDiagnostics.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                "\(Self.timestampFormatter.string(from: entry.timestamp)) [\(entry.level.uppercased())]"
                            )
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                            Text(entry.message)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Sync Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy") {
                    UIPasteboard.general.string = diagnosticDump
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var diagnosticDump: String {
        var lines: [String] = []
        lines.append("Transient Banner: \(syncMonitor.transientErrorMessage ?? "None")")
        lines.append("Last Error Domain: \(syncMonitor.lastCloudKitErrorDomain ?? "None")")
        lines.append("Last Error Code: \(syncMonitor.lastCloudKitErrorCode.map(String.init) ?? "None")")
        lines.append("Last Error Description: \(syncMonitor.lastCloudKitErrorDescription ?? "None")")
        lines.append(
            "Last Success: \(syncMonitor.lastSuccessfulSyncDate.map(Self.timestampFormatter.string(from:)) ?? "None")"
        )
        lines.append("")
        lines.append("Recent Events:")
        for entry in syncMonitor.recentDiagnostics {
            lines.append(
                "\(Self.timestampFormatter.string(from: entry.timestamp)) [\(entry.level.uppercased())] \(entry.message)"
            )
        }
        return lines.joined(separator: "\n")
    }
}
