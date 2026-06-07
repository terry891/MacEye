import Foundation

/// Pure, dependency-free time math for break scheduling. Unit-tested in isolation.
enum ScheduleMath {
    /// Next break fires one normal interval from now.
    static func normalNextFire(now: Date, intervalMinutes: Int) -> Date {
        now.addingTimeInterval(Double(intervalMinutes) * 60)
    }

    /// Snooze postpones the next break by a short fixed amount.
    static func snoozedNextFire(now: Date, snoozeMinutes: Int) -> Date {
        now.addingTimeInterval(Double(snoozeMinutes) * 60)
    }

    /// Pausing suppresses breaks for the pause window, then resumes a fresh interval.
    static func pausedNextFire(now: Date, pauseMinutes: Int, intervalMinutes: Int) -> Date {
        now.addingTimeInterval(Double(pauseMinutes) * 60 + Double(intervalMinutes) * 60)
    }

    /// Whole seconds until `date`, never negative.
    static func secondsUntil(_ date: Date, from now: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now).rounded()))
    }

    /// True when a scheduled fire time has already elapsed (e.g. during sleep).
    static func isMissed(fire: Date, now: Date) -> Bool {
        now >= fire
    }
}
