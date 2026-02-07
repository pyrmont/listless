import SwiftUI

struct ShortcutKey: Hashable {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    init(key: KeyEquivalent, modifiers: EventModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    static func == (lhs: ShortcutKey, rhs: ShortcutKey) -> Bool {
        lhs.key == rhs.key && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(modifiers.rawValue)
    }
}

extension View {
    func keyboardNavigation(_ bindings: [ShortcutKey: () -> KeyPress.Result]) -> some View {
        self.onKeyPress { press in
            let key = normalizeKey(press)
            let modifiers = normalizeModifiers(press.modifiers)
            let shortcut = ShortcutKey(key: key, modifiers: modifiers)

            if let action = bindings[shortcut] {
                return action()
            }
            return .ignored
        }
    }

    private func normalizeKey(_ press: KeyPress) -> KeyEquivalent {
        // Normalize backspace/delete key
        if press.characters == "\u{7F}" {
            return .delete
        }
        return press.key
    }

    private func normalizeModifiers(_ modifiers: EventModifiers) -> EventModifiers {
        // Filter out system modifiers that come automatically with certain keys
        // (function keys, numericPad) - only keep user-intentional modifiers
        var normalized = modifiers
        normalized.remove(.function)
        normalized.remove(.numericPad)
        return normalized
    }
}
