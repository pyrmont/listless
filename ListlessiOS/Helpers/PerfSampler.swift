import Foundation
import UIKit

/// Lightweight timing collector for diagnosing cold-launch hitches without
/// needing Instruments. Samples live in memory during a launch and are flushed
/// to disk when the app backgrounds, so the next launch can display prior data
/// from the in-app debug screen. Call indexes restart at 0 per launch so the
/// first-invocation cost of each label is easy to spot.
@MainActor
final class PerfSampler {
    static let shared = PerfSampler()

    struct Sample: Codable, Identifiable {
        var id = UUID()
        let launchID: UUID
        let label: String
        let callIndex: Int
        let durationMs: Double
        let msSinceLaunch: Double
        let timestamp: Date
    }

    struct Launch: Codable, Identifiable {
        var id: UUID { launchID }
        let launchID: UUID
        let startedAt: Date
    }

    private let storageURL: URL
    private let maxTotalSamples = 1000
    private let maxPerLabelPerLaunch = 40

    private(set) var currentLaunch: Launch
    private var launches: [Launch] = []
    private var samples: [Sample] = []
    private var callCounts: [String: Int] = [:]
    private let launchClockStart: DispatchTime
    private var dirty = false

    private init() {
        let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        storageURL = (dir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PerfSamples.json")

        let launch = Launch(launchID: UUID(), startedAt: Date())
        currentLaunch = launch
        launchClockStart = DispatchTime.now()
        load()
        launches.append(launch)
        dirty = true

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in PerfSampler.shared.flush() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in PerfSampler.shared.flush() }
        }
    }

    @discardableResult
    func measure<T>(_ label: String, _ work: () -> T) -> T {
        let start = DispatchTime.now()
        let result = work()
        let elapsedNs = DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds
        record(label: label, durationMs: Double(elapsedNs) / 1_000_000)
        return result
    }

    func record(label: String, durationMs: Double) {
        let index = callCounts[label, default: 0]
        callCounts[label] = index + 1
        guard index < maxPerLabelPerLaunch else { return }

        let sinceLaunchNs = DispatchTime.now().uptimeNanoseconds
            &- launchClockStart.uptimeNanoseconds
        let sample = Sample(
            launchID: currentLaunch.launchID,
            label: label,
            callIndex: index,
            durationMs: durationMs,
            msSinceLaunch: Double(sinceLaunchNs) / 1_000_000,
            timestamp: Date()
        )
        samples.append(sample)
        if samples.count > maxTotalSamples {
            samples.removeFirst(samples.count - maxTotalSamples)
        }
        dirty = true
    }

    func allSamples() -> [Sample] { samples }
    func allLaunches() -> [Launch] { launches }

    func samplesForCurrentLaunch() -> [Sample] {
        samples.filter { $0.launchID == currentLaunch.launchID }
    }

    func clear() {
        samples.removeAll()
        launches = [currentLaunch]
        callCounts.removeAll()
        dirty = true
        flush()
    }

    func flush() {
        guard dirty else { return }
        let payload = StoredPayload(launches: launches, samples: samples)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
            dirty = false
        } catch {
            // Best-effort: swallow errors; debug data is non-critical.
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let payload = try? JSONDecoder().decode(StoredPayload.self, from: data)
        else { return }
        launches = payload.launches.suffix(20)
        let keepIDs = Set(launches.map(\.launchID))
        samples = payload.samples.filter { keepIDs.contains($0.launchID) }
    }

    private struct StoredPayload: Codable {
        let launches: [Launch]
        let samples: [Sample]
    }
}
