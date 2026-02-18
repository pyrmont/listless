import SwiftUI

private struct TaskAccentColorKey: Hashable {
    let index: Int
    let total: Int
}

@MainActor
private enum TaskAccentColorCache {
    static var colors: [TaskAccentColorKey: Color] = [:]
}

func taskColor(forIndex index: Int, total: Int) -> Color {
    guard total > 1 else { return Color(hue: 0.98, saturation: 0.85, brightness: 1.0) }

    // Gradient matches gradient.png: coral/red → pink/magenta → purple/blue
    let progress = Double(index) / Double(total - 1)
    let top    = (h: 0.98, s: 0.85, b: 1.00)
    let mid    = (h: 0.88, s: 0.75, b: 0.95)
    let bottom = (h: 0.72, s: 0.65, b: 0.85)

    if progress < 0.5 {
        return interpolateHSB(from: top, to: mid, progress: progress * 2.0)
    } else {
        return interpolateHSB(from: mid, to: bottom, progress: (progress - 0.5) * 2.0)
    }
}

@MainActor
func cachedTaskColor(forIndex index: Int, total: Int) -> Color {
    let key = TaskAccentColorKey(index: index, total: total)
    if let cached = TaskAccentColorCache.colors[key] {
        return cached
    }

    let computed = taskColor(forIndex: index, total: total)
    TaskAccentColorCache.colors[key] = computed
    return computed
}

private func interpolateHSB(
    from: (h: Double, s: Double, b: Double),
    to: (h: Double, s: Double, b: Double),
    progress: Double
) -> Color {
    Color(
        hue: from.h + (to.h - from.h) * progress,
        saturation: from.s + (to.s - from.s) * progress,
        brightness: from.b + (to.b - from.b) * progress
    )
}
