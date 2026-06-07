import Cocoa

/// Drives break timing. Holds the next fire date and a one-shot timer, re-arming
/// after each break. Pure date math is delegated to ScheduleMath.
final class BreakScheduler {
    enum State {
        case running
        case breaking
        case paused(until: Date)
    }

    private let config: Config
    private var timer: Timer?
    private(set) var state: State = .running
    private(set) var nextFire: Date = .distantFuture

    /// Called (on main thread) when it is time to show the break overlay.
    var onBreak: (() -> Void)?

    init(config: Config) {
        self.config = config
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    // MARK: Public control

    func start() { scheduleNormal() }

    func scheduleNormal() {
        state = .running
        nextFire = Date().addingTimeInterval(normalInterval())
        armTimer()
    }

    func snooze(minutes: Int = 5) {
        state = .running
        nextFire = ScheduleMath.snoozedNextFire(now: Date(), snoozeMinutes: minutes)
        armTimer()
    }

    func pause(minutes: Int) {
        let until = Date().addingTimeInterval(Double(minutes) * 60)
        state = .paused(until: until)
        nextFire = ScheduleMath.pausedNextFire(
            now: Date(), pauseMinutes: minutes, intervalMinutes: config.intervalMinutes)
        armTimer()
    }

    func resume() { scheduleNormal() }

    /// Force a break immediately (menu: Take Break Now).
    func triggerBreakNow() { fire() }

    /// Called by OverlayController when the break ends; starts the next interval.
    func breakDidFinish() { scheduleNormal() }

    var secondsUntilNextBreak: Int { ScheduleMath.secondsUntil(nextFire, from: Date()) }

    var isPaused: Bool {
        if case .paused(let until) = state { return until > Date() }
        return false
    }

    // MARK: Internals

    /// Normal interval in seconds; honors EYEBREAK_DEBUG_SECONDS for fast manual testing.
    private func normalInterval() -> TimeInterval {
        if let s = ProcessInfo.processInfo.environment["EYEBREAK_DEBUG_SECONDS"],
           let v = Double(s), v > 0 {
            return v
        }
        return Double(config.intervalMinutes) * 60
    }

    private func armTimer() {
        timer?.invalidate()
        let delay = max(1, nextFire.timeIntervalSinceNow)
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.fire()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        if case .breaking = state { return }  // re-entrancy guard
        state = .breaking
        onBreak?()
    }

    @objc private func handleWake() {
        if case .breaking = state { return }
        if ScheduleMath.isMissed(fire: nextFire, now: Date()) {
            fire()           // at most one catch-up break after sleep
        } else {
            armTimer()       // re-arm against wall clock
        }
    }
}
