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
        // Mask to only meaningful shortcut modifiers, excluding system artifacts
        // like .function (deprecated), .numericPad, .capsLock, etc.
        let shortcutModifierMask: EventModifiers = [.command, .shift, .option, .control]
        return EventModifiers(rawValue: modifiers.rawValue & shortcutModifierMask.rawValue)
    }
}
