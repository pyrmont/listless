import UIKit

/// Pre-pays the ~400ms `RemoteTextInput` / autocorrect subsystem spin-up that
/// otherwise happens on the first real text field focus after a cold launch.
/// Creates an offscreen `UITextField`, makes it first responder, then resigns
/// immediately — enough to trigger the keyboard process to initialize without
/// visibly animating anything.
@MainActor
enum KeyboardWarmup {
    private static var didWarm = false

    static func prime() {
        guard !didWarm else { return }
        guard let window = keyWindow() else { return }
        didWarm = true

        PerfSampler.shared.measure("Keyboard.warmup") {
            let field = UITextField(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
            field.autocorrectionType = .default
            field.autocapitalizationType = .sentences
            window.addSubview(field)
            field.becomeFirstResponder()
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
    }

    private static func keyWindow() -> UIWindow? {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let key = scene.windows.first(where: \.isKeyWindow) {
                return key
            }
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let first = scene.windows.first {
                return first
            }
        }
        return nil
    }
}
