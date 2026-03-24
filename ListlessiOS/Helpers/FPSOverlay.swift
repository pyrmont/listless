import SwiftUI
import UIKit

struct FPSOverlay: View {
    @State private var fps: Int = 0
    @State private var targetFPS: Int = 0
    @State private var monitor = FPSMonitor()

    var body: some View {
        Text("\(fps) / \(targetFPS) FPS")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(fps >= 55 ? .green : fps >= 45 ? .yellow : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: Capsule())
            .onAppear {
                monitor.start { actual, target in
                    fps = actual
                    targetFPS = target
                }
            }
            .onDisappear {
                monitor.stop()
            }
    }
}

@MainActor
private class FPSMonitor {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastTargetFPS: Int = 0
    private var onUpdate: ((Int, Int) -> Void)?

    func start(onUpdate: @escaping (Int, Int) -> Void) {
        self.onUpdate = onUpdate
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let interval = link.targetTimestamp - link.timestamp
        if interval > 0 {
            lastTargetFPS = Int(round(1.0 / interval))
        }
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            onUpdate?(frameCount, lastTargetFPS)
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}
