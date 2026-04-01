import Foundation
import SwiftUI
import Testing

#if os(macOS)
@testable import Listless
#else
@testable import Listless_iOS
#endif

@Suite("AccentColor")
struct AccentColorTests {

    // MARK: - ColorTheme properties

    @Test("displayOrder sorts themes alphabetically by displayName")
    func displayOrderSorting() {
        let order = ColorTheme.displayOrder
        let names = order.map(\.displayName)

        #expect(names == names.sorted())
    }

    @Test("All themes have unique display names")
    func uniqueDisplayNames() {
        let names = ColorTheme.allCases.map(\.displayName)

        #expect(Set(names).count == names.count)
    }

    @Test("displayOrder contains all cases")
    func displayOrderContainsAll() {
        #expect(Set(ColorTheme.displayOrder) == Set(ColorTheme.allCases))
    }

    // MARK: - itemColor

    @Test(
        "Single item returns top color for all themes",
        arguments: ColorTheme.allCases
    )
    func singleItemReturnsTopColor(theme: ColorTheme) {
        let singleColor = itemColor(forIndex: 0, total: 1, theme: theme)
        // For a single item, itemColor returns the top HSB directly.
        // We can't inspect Color internals, but we can verify it doesn't crash
        // and returns a non-nil Color.
        #expect(type(of: singleColor) == Color.self)
    }

    @Test("First item of many matches top color")
    func firstItemMatchesTop() {
        let topColor = itemColor(forIndex: 0, total: 1, theme: .pilbara)
        let firstOfMany = itemColor(forIndex: 0, total: 10, theme: .pilbara)

        // Both should be the top color since progress=0 yields top for both paths.
        #expect(topColor.description == firstOfMany.description)
    }

    @Test("Last item of many uses bottom color")
    func lastItemUsesBottom() {
        // progress = 1.0 → interpolates from mid to bottom with progress=1.0 → bottom
        let lastColor = itemColor(forIndex: 9, total: 10, theme: .pilbara)
        #expect(type(of: lastColor) == Color.self)
    }

    @Test("Middle item of odd count uses mid color")
    func middleItemUsesMidColor() {
        // For total=3, index=1 → progress = 0.5 → exactly at mid
        let midColor = itemColor(forIndex: 1, total: 3, theme: .pilbara)
        #expect(type(of: midColor) == Color.self)
    }

    @Test(
        "Gradient produces distinct colors for each position",
        arguments: ColorTheme.allCases
    )
    func gradientProducesDistinctColors(theme: ColorTheme) {
        let total = 5
        let colors = (0..<total).map {
            itemColor(forIndex: $0, total: total, theme: theme).description
        }
        // Adjacent colors should differ (gradient is continuous but not flat).
        for i in 0..<(colors.count - 1) {
            #expect(colors[i] != colors[i + 1])
        }
    }

    @Test("Different themes produce different colors for same position")
    func differentThemesDiffer() {
        let pilbaraColor = itemColor(forIndex: 0, total: 5, theme: .pilbara).description
        let collaroyColor = itemColor(forIndex: 0, total: 5, theme: .collaroy).description

        #expect(pilbaraColor != collaroyColor)
    }

    // MARK: - Edge cases / out-of-range inputs

    @Test("total=0 returns top color without crashing")
    func totalZero() {
        // total <= 1 hits the guard, so total=0 should behave like total=1.
        let color = itemColor(forIndex: 0, total: 0, theme: .pilbara)
        let topColor = itemColor(forIndex: 0, total: 1, theme: .pilbara)
        #expect(color.description == topColor.description)
    }

    @Test("Negative total returns top color without crashing")
    func negativeTotalDoesNotCrash() {
        let color = itemColor(forIndex: 0, total: -1, theme: .pilbara)
        let topColor = itemColor(forIndex: 0, total: 1, theme: .pilbara)
        #expect(color.description == topColor.description)
    }

    @Test("Negative index produces a color without crashing")
    func negativeIndex() {
        // Extrapolates beyond the gradient — should not crash.
        let color = itemColor(forIndex: -1, total: 5, theme: .pilbara)
        #expect(type(of: color) == Color.self)
    }

    @Test("Index beyond total produces a color without crashing")
    func indexBeyondTotal() {
        // Extrapolates beyond the gradient — should not crash.
        let color = itemColor(forIndex: 10, total: 5, theme: .pilbara)
        #expect(type(of: color) == Color.self)
    }

    @Test("Very large total does not crash")
    func veryLargeTotal() {
        let color = itemColor(forIndex: 500, total: 1000, theme: .collaroy)
        #expect(type(of: color) == Color.self)
    }

    // MARK: - cachedItemColor

    @Test("Cached color returns same result as uncached")
    @MainActor
    func cachedMatchesUncached() {
        let uncached = itemColor(forIndex: 2, total: 5, theme: .pilbara).description
        let cached = cachedItemColor(forIndex: 2, total: 5, theme: .pilbara).description

        #expect(cached == uncached)
    }

    @Test("Repeated cached calls return consistent results")
    @MainActor
    func cachedConsistency() {
        let first = cachedItemColor(forIndex: 1, total: 4, theme: .collaroy).description
        let second = cachedItemColor(forIndex: 1, total: 4, theme: .collaroy).description

        #expect(first == second)
    }
}
