import SwiftUI

enum ColorTheme: Int, CaseIterable, Identifiable {
    case pilbara = 0
    case collaroy = 1

    var id: Int { rawValue }

    static var displayOrder: [ColorTheme] {
        allCases.sorted { $0.displayName < $1.displayName }
    }

    var displayName: String {
        switch self {
        case .pilbara: "Pilbara"
        case .collaroy: "Collaroy"
        }
    }

    fileprivate typealias HSB = (h: Double, s: Double, b: Double)

    fileprivate var top: HSB {
        switch self {
        case .pilbara: (h: 0.98, s: 0.85, b: 1.00)
        case .collaroy: (h: 0.58, s: 0.88, b: 1.00)
        }
    }

    fileprivate var mid: HSB {
        switch self {
        case .pilbara: (h: 0.88, s: 0.75, b: 0.95)
        case .collaroy: (h: 0.51, s: 0.69, b: 0.90)
        }
    }

    fileprivate var bottom: HSB {
        switch self {
        case .pilbara: (h: 0.72, s: 0.65, b: 0.85)
        case .collaroy: (h: 0.44, s: 0.50, b: 0.80)
        }
    }
}

private struct ItemAccentColorKey: Hashable {
    let index: Int
    let total: Int
    let theme: ColorTheme
}

@MainActor
private enum ItemAccentColorCache {
    static var colors: [ItemAccentColorKey: Color] = [:]
}

func itemColor(forIndex index: Int, total: Int, theme: ColorTheme = .pilbara) -> Color {
    let top = theme.top
    guard total > 1 else { return Color(hue: top.h, saturation: top.s, brightness: top.b) }

    let progress = Double(index) / Double(total - 1)
    let mid = theme.mid
    let bottom = theme.bottom

    if progress < 0.5 {
        return interpolateHSB(from: top, to: mid, progress: progress * 2.0)
    } else {
        return interpolateHSB(from: mid, to: bottom, progress: (progress - 0.5) * 2.0)
    }
}

@MainActor
func cachedItemColor(forIndex index: Int, total: Int, theme: ColorTheme = .pilbara) -> Color {
    let key = ItemAccentColorKey(index: index, total: total, theme: theme)
    if let cached = ItemAccentColorCache.colors[key] {
        return cached
    }

    let computed = itemColor(forIndex: index, total: total, theme: theme)
    ItemAccentColorCache.colors[key] = computed
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
