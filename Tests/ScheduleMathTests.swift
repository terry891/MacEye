import Foundation

// Minimal assertion harness (no XCTest needed for a single pure file).
// Uses @main so it can be compiled alongside ScheduleMath.swift (multi-file
// compilation forbids top-level code outside main.swift).
@main
struct ScheduleMathTests {
    static var failures = 0

    static func check(_ cond: Bool, _ msg: String) {
        if !cond { failures += 1; print("FAIL: \(msg)") } else { print("ok: \(msg)") }
    }

    static func main() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)

        // normalNextFire = now + interval minutes
        check(ScheduleMath.normalNextFire(now: t0, intervalMinutes: 30) == t0.addingTimeInterval(1800),
              "normalNextFire 30min")
        check(ScheduleMath.normalNextFire(now: t0, intervalMinutes: 20) == t0.addingTimeInterval(1200),
              "normalNextFire 20min")

        // snoozedNextFire = now + snooze minutes
        check(ScheduleMath.snoozedNextFire(now: t0, snoozeMinutes: 5) == t0.addingTimeInterval(300),
              "snoozedNextFire 5min")

        // pausedNextFire = now + pause minutes + interval minutes (fresh interval after pause)
        check(ScheduleMath.pausedNextFire(now: t0, pauseMinutes: 60, intervalMinutes: 30) == t0.addingTimeInterval(5400),
              "pausedNextFire 60+30min")

        // secondsUntil clamps at 0 and rounds
        check(ScheduleMath.secondsUntil(t0.addingTimeInterval(125), from: t0) == 125, "secondsUntil future")
        check(ScheduleMath.secondsUntil(t0.addingTimeInterval(-10), from: t0) == 0, "secondsUntil past clamps to 0")

        // isMissed true when fire <= now
        check(ScheduleMath.isMissed(fire: t0.addingTimeInterval(-1), now: t0) == true, "isMissed past")
        check(ScheduleMath.isMissed(fire: t0.addingTimeInterval(60), now: t0) == false, "isMissed future")

        if failures == 0 { print("ALL PASSED") } else { print("\(failures) FAILED"); exit(1) }
    }
}
