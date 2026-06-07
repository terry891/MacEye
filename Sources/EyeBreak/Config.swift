import Foundation

/// Persistent user settings, backed by UserDefaults with first-run defaults.
final class Config {
    static let shared = Config()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let interval = "intervalMinutes"
        static let breakSeconds = "breakSeconds"
        static let sound = "soundEnabled"
        static let openAtLogin = "openAtLogin"
        static let seeded = "didSeedDefaults"
    }

    init() {
        if !defaults.bool(forKey: Keys.seeded) {
            defaults.set(30, forKey: Keys.interval)
            defaults.set(20, forKey: Keys.breakSeconds)
            defaults.set(true, forKey: Keys.sound)
            defaults.set(true, forKey: Keys.openAtLogin)
            defaults.set(true, forKey: Keys.seeded)
        }
    }

    var intervalMinutes: Int {
        get { defaults.integer(forKey: Keys.interval) }
        set { defaults.set(newValue, forKey: Keys.interval) }
    }
    var breakSeconds: Int {
        get { defaults.integer(forKey: Keys.breakSeconds) }
        set { defaults.set(newValue, forKey: Keys.breakSeconds) }
    }
    var soundEnabled: Bool {
        get { defaults.bool(forKey: Keys.sound) }
        set { defaults.set(newValue, forKey: Keys.sound) }
    }
    var openAtLogin: Bool {
        get { defaults.bool(forKey: Keys.openAtLogin) }
        set { defaults.set(newValue, forKey: Keys.openAtLogin) }
    }
}
