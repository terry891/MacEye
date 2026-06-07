import Cocoa

/// Friendly rotating reminder copy + a rounded-system-font helper for the cute UI.
enum Messages {
    static let lines = [
        "Look 20 feet away and blink a few times 👀",
        "Eyes off the screen — you've earned a breather ✨",
        "Roll your shoulders and gaze into the distance 🌿",
        "Quick reset! Soften your focus for a moment 💆",
        "Peek out a window — let your eyes wander 🪟",
        "Deep breath. Relax your eyes. You've got this 💚",
    ]

    /// Deterministic rotation (no RNG): advances by call count, persisted in UserDefaults.
    static func next() -> String {
        let key = "messageIndex"
        let idx = UserDefaults.standard.integer(forKey: key)
        let line = lines[idx % lines.count]
        UserDefaults.standard.set(idx + 1, forKey: key)
        return line
    }

    static func rounded(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: d, size: size) ?? base
        }
        return base
    }
}
