import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = Config.shared
    private var scheduler: BreakScheduler!
    private var menuBar: MenuBarController!
    private let overlay = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler = BreakScheduler(config: config)
        scheduler.onBreak = { [weak self] in self?.presentBreak() }

        menuBar = MenuBarController(scheduler: scheduler, config: config)
        menuBar.onTakeBreakNow = { [weak self] in self?.scheduler.triggerBreakNow() }

        scheduler.start()
        LoginItem.set(enabled: config.openAtLogin)
        NSLog("EyeBreak launched; first break in \(scheduler.secondsUntilNextBreak)s")
    }

    private func presentBreak() {
        overlay.show(breakSeconds: config.breakSeconds,
                     message: Messages.next(),
                     playSound: config.soundEnabled) { [weak self] in
            self?.scheduler.breakDidFinish()
        }
    }
}
