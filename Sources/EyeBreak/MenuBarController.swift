import Cocoa

/// The menu-bar eye icon and its dropdown. Rebuilds the menu on open so checkmarks
/// and the "next break" line are always current.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let scheduler: BreakScheduler
    private let config: Config
    var onTakeBreakNow: (() -> Void)?

    private let intervals = [20, 25, 30, 45, 60]
    private let breakLengths = [10, 20, 30, 60]

    init(scheduler: BreakScheduler, config: Config) {
        self.scheduler = scheduler
        self.config = config
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeBreak")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Status line.
        let status: String
        if scheduler.isPaused {
            status = "Paused · resumes in \(minutes(scheduler.secondsUntilNextBreak))"
        } else {
            status = "Next break in \(minutes(scheduler.secondsUntilNextBreak))"
        }
        let statusRow = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusRow.isEnabled = false
        menu.addItem(statusRow)
        menu.addItem(.separator())

        menu.addItem(item("Take Break Now", #selector(takeBreakNow)))
        menu.addItem(item("Snooze 5 min", #selector(snooze)))

        // Pause submenu.
        let pause = NSMenu()
        pause.addItem(item("15 minutes", #selector(pause15)))
        pause.addItem(item("1 hour", #selector(pause60)))
        pause.addItem(.separator())
        pause.addItem(item("Resume", #selector(resume)))
        let pauseRow = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
        pauseRow.submenu = pause
        menu.addItem(pauseRow)

        menu.addItem(.separator())

        // Interval submenu.
        let intervalMenu = NSMenu()
        for m in intervals {
            let it = item("\(m) min", #selector(setInterval(_:)))
            it.tag = m
            it.state = (config.intervalMinutes == m) ? .on : .off
            intervalMenu.addItem(it)
        }
        let intervalRow = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        intervalRow.submenu = intervalMenu
        menu.addItem(intervalRow)

        // Break length submenu.
        let lenMenu = NSMenu()
        for s in breakLengths {
            let it = item("\(s) sec", #selector(setBreakLength(_:)))
            it.tag = s
            it.state = (config.breakSeconds == s) ? .on : .off
            lenMenu.addItem(it)
        }
        let lenRow = NSMenuItem(title: "Break length", action: nil, keyEquivalent: "")
        lenRow.submenu = lenMenu
        menu.addItem(lenRow)

        // Toggles.
        let sound = item("Sound", #selector(toggleSound))
        sound.state = config.soundEnabled ? .on : .off
        menu.addItem(sound)

        let login = item("Open at Login", #selector(toggleLogin))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit EyeBreak", #selector(quit)))
    }

    // MARK: Helpers

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    private func minutes(_ seconds: Int) -> String {
        let m = Int((Double(seconds) / 60).rounded(.up))
        return m <= 1 ? "1 min" : "\(m) min"
    }

    // MARK: Actions

    @objc private func takeBreakNow() { onTakeBreakNow?() }
    @objc private func snooze() { scheduler.snooze(minutes: 5) }
    @objc private func pause15() { scheduler.pause(minutes: 15) }
    @objc private func pause60() { scheduler.pause(minutes: 60) }
    @objc private func resume() { scheduler.resume() }
    @objc private func setInterval(_ sender: NSMenuItem) {
        config.intervalMinutes = sender.tag
        scheduler.scheduleNormal()
    }
    @objc private func setBreakLength(_ sender: NSMenuItem) {
        config.breakSeconds = sender.tag
    }
    @objc private func toggleSound() { config.soundEnabled.toggle() }
    @objc private func toggleLogin() {
        let newValue = !LoginItem.isEnabled
        LoginItem.set(enabled: newValue)
        config.openAtLogin = newValue
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
