import SwiftUI
import UIKit

struct PerfDebugView: View {
    @State private var refreshTick = 0

    var body: some View {
        List {
            Section("Summary (current launch)") {
                let stats = perLabelStats(for: PerfSampler.shared.samplesForCurrentLaunch())
                if stats.isEmpty {
                    Text("No samples yet. Interact with the app and return here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stats, id: \.label) { stat in
                        StatRow(stat: stat)
                    }
                }
            }

            ForEach(launchesMostRecentFirst()) { launch in
                Section(sectionTitle(for: launch)) {
                    let launchSamples = samples(for: launch.launchID)
                    if launchSamples.isEmpty {
                        Text("No samples recorded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(launchSamples) { sample in
                            SampleRow(sample: sample)
                        }
                    }
                }
            }
        }
        .id(refreshTick)
        .navigationTitle("Perf Samples")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refresh") { refreshTick &+= 1 }
                    Button("Copy Summary") { copySummary() }
                    Button("Clear All", role: .destructive) {
                        PerfSampler.shared.clear()
                        refreshTick &+= 1
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func launchesMostRecentFirst() -> [PerfSampler.Launch] {
        PerfSampler.shared.allLaunches().sorted { $0.startedAt > $1.startedAt }
    }

    private func samples(for launchID: UUID) -> [PerfSampler.Sample] {
        PerfSampler.shared.allSamples()
            .filter { $0.launchID == launchID }
            .sorted { $0.msSinceLaunch < $1.msSinceLaunch }
    }

    private func sectionTitle(for launch: PerfSampler.Launch) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm:ss"
        let isCurrent = launch.launchID == PerfSampler.shared.currentLaunch.launchID
        return formatter.string(from: launch.startedAt) + (isCurrent ? " (current)" : "")
    }

    private func perLabelStats(for samples: [PerfSampler.Sample]) -> [LabelStat] {
        let grouped = Dictionary(grouping: samples, by: \.label)
        return grouped.map { label, entries in
            let sorted = entries.sorted(by: { $0.callIndex < $1.callIndex })
            let durations = sorted.map(\.durationMs)
            return LabelStat(
                label: label,
                count: sorted.count,
                firstCallMs: durations.first ?? 0,
                medianMs: median(durations),
                maxMs: durations.max() ?? 0,
                firstCallMsSinceLaunch: sorted.first?.msSinceLaunch ?? 0
            )
        }
        .sorted { $0.firstCallMs > $1.firstCallMs }
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private func copySummary() {
        var lines: [String] = []
        for launch in launchesMostRecentFirst() {
            lines.append("=== Launch \(launch.startedAt) ===")
            let stats = perLabelStats(for: samples(for: launch.launchID))
            for stat in stats {
                lines.append(String(
                    format: "%@  n=%d  first=%.2fms  median=%.2fms  max=%.2fms  firstAt=%.0fms",
                    stat.label,
                    stat.count,
                    stat.firstCallMs,
                    stat.medianMs,
                    stat.maxMs,
                    stat.firstCallMsSinceLaunch
                ))
            }
            lines.append("")
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }
}

private struct LabelStat {
    let label: String
    let count: Int
    let firstCallMs: Double
    let medianMs: Double
    let maxMs: Double
    let firstCallMsSinceLaunch: Double
}

private struct StatRow: View {
    let stat: LabelStat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.label)
                .font(.callout.monospaced())
            HStack(spacing: 12) {
                Text("n=\(stat.count)")
                Text(String(format: "1st=%.1fms", stat.firstCallMs))
                    .foregroundStyle(stat.firstCallMs > 16 ? .red : .primary)
                Text(String(format: "med=%.1f", stat.medianMs))
                Text(String(format: "max=%.1f", stat.maxMs))
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            Text(String(format: "first call at %.0f ms since launch", stat.firstCallMsSinceLaunch))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private struct SampleRow: View {
    let sample: PerfSampler.Sample

    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "%5.0fms", sample.msSinceLaunch))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("#\(sample.callIndex)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .leading)
            Text(shortLabel(sample.label))
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(String(format: "%.2f ms", sample.durationMs))
                .font(.caption.monospaced())
                .foregroundStyle(sample.durationMs > 16 ? .red : .primary)
        }
    }

    private func shortLabel(_ label: String) -> String {
        if let range = label.range(of: ".") {
            return String(label[range.upperBound...])
        }
        return label
    }
}
