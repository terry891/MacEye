# EyeBreak — Eye-Strain Break Reminder (macOS)

**Date:** 2026-06-07
**Status:** Approved design — ready for implementation plan
**Platform:** macOS 26.4 (Apple Silicon), Swift 6.3.2, Command Line Tools

## Problem

The user spends hours staring at the screen and wants a lightweight macOS app/service
that always runs in the background and forces a periodic break to relax the eyes and avoid
eye strain. Default cadence: every 30 minutes. Reminders must be hard to ignore.

## Goals

- Always-running, low-footprint background app that starts at login.
- A reminder that is genuinely noticeable: a **full-screen break overlay** with a countdown.
- **Menu-bar control** (no dock icon) for pause / snooze / interval / quit.
- **Configurable** interval (default 30 min) and break length (default 20 s).
- **Modern, cute UI** — friendly, soft, animated, delightful rather than clinical.

## Non-Goals (YAGNI)

- No analytics, streaks, history, or cloud sync.
- No preferences window in v1 — all controls live in the menu bar.
- No notarization / Developer ID signing — ad-hoc local signing only.
- No App Store packaging.

## Approach

A single self-contained native **`EyeBreak.app`** bundle compiled directly with `swiftc`
(no Xcode project, no SwiftPM dependency resolution, no third-party libraries). Native AppKit
gives us a real menu-bar status item, true multi-display full-screen overlays, and the modern
`SMAppService` login-item API — all with a tiny native footprint.

Rejected alternatives:
- **Python (`rumps` + PyObjC):** needs Python + pip deps, slower startup, awkward `.app`
  packaging. Not "lightweight."
- **Shell + LaunchAgent + osascript:** cannot produce a real menu-bar icon or a true
  full-screen overlay cleanly.

## Architecture

Accessory app (`LSUIElement = true`, `NSApplication.activationPolicy = .accessory`) → no dock
icon, menu-bar only. Components, each with one clear responsibility:

### `Config`
`UserDefaults`-backed settings store with sensible defaults and live updates.

| Key              | Default                              | Notes                          |
|------------------|--------------------------------------|--------------------------------|
| `intervalMinutes`| `30`                                 | Choices: 20/25/30/45/60        |
| `breakSeconds`   | `20`                                 | Choices: 10/20/30/60           |
| `soundEnabled`   | `true`                               | Gentle chime on break start    |
| `openAtLogin`    | `true` (set on first run)            | Mirrors `SMAppService` state   |

Reminder copy is a small rotating set of friendly messages (see UI section), not user-editable
in v1.

### `BreakScheduler`
Owns the active `Timer` and **all time math** — the pure, testable core.

- Computes `nextFireDate` from `now`, `intervalMinutes`, and any active snooze/pause.
- State machine: `running` → `breaking` → `running`; plus `pausedUntil(Date)` and
  `snoozedUntil(Date)`.
- Re-entrancy guard: never opens a second overlay while `breaking`.
- Sleep/wake: on `NSWorkspace.didWakeNotification`, recompute against wall-clock so a long
  sleep does not fire a burst of missed breaks — at most one catch-up, then resume normal cadence.
- Exposes pure functions for tests, e.g.
  `nextFireDate(now:interval:pausedUntil:snoozedUntil:) -> Date` and
  `secondsUntilNextBreak(now:) -> Int`.

### `MenuBarController`
`NSStatusItem` with an SF Symbol eye icon (`eye` / `eyes`). Menu:

- **"Next break in N min"** — live status line (disabled), refreshed ~every 15 s.
- **Take Break Now**
- **Snooze 5 min**
- **Pause ▸** — 15 min / 1 hour / Resume (checkmark shows current pause state)
- **Interval ▸** — 20 / 25 / 30 / 45 / 60 min (checkmark on current)
- **Break length ▸** — 10 / 20 / 30 / 60 s (checkmark on current)
- **Sound** — toggle (checkmark)
- **Open at Login** — toggle (checkmark)
- **Quit EyeBreak**

Menu actions mutate `Config`/`BreakScheduler` and reschedule live.

### `OverlayController`
On break, presents the cute full-screen experience:

- One borderless `NSWindow` **per `NSScreen`**, `level = .screenSaver`, ignores mouse-through
  only on the active card, covers the full frame including menu bar area
  (`NSWindow.CollectionBehavior` = `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`).
- Rebuilds on `NSApplication.didChangeScreenParametersNotification` (display hot-plug).
- Auto-closes after `breakSeconds`; **Skip** button or **ESC** ends early.
- On close → notifies `BreakScheduler` to schedule the next interval.
- Optional gentle system sound on appear when `soundEnabled`.

### `LoginItem`
Thin wrapper over `SMAppService.mainApp` `register()` / `unregister()` / status. Handles the
"approval pending" case gracefully (no crash; menu reflects best-known state). On first launch,
attempts to register so the app truly "always runs in the background."

## Data Flow

```
launch
  └─ load Config
     └─ BreakScheduler.start()         (schedule Timer for nextFireDate)
        └─ Timer fires  ──►  guard !breaking
           └─ OverlayController.show(on: all screens)   (+ optional sound)
              └─ Skip / ESC / countdown == 0
                 └─ OverlayController.dismiss()
                    └─ BreakScheduler.scheduleNext()     (loop)

menu actions ─► mutate Config / Scheduler ─► reschedule live
sleep/wake   ─► recompute nextFireDate vs wall-clock (no burst)
screen change─► OverlayController rebuilds windows if breaking
```

## UI / Visual Style — "Modern & Cute"

Direction: soft, friendly, delightful — like a gentle wellness app, not a system error.

**Full-screen overlay**
- Background: dark translucent **blur** via `NSVisualEffectView` (`.hudWindow` / `.fullScreenUI`
  material, `.behindWindow` blending) so the desktop is softly obscured, not harshly blacked out.
- Centered **rounded card** (large corner radius ~28pt) with a soft shadow and a subtle
  vertical **gradient** (calm tones, e.g. indigo → teal/pink pastel), semi-transparent.
- A cute **mascot**: a large 👀 / 👁 glyph (or two eyes) with a slow **breathing/pulse**
  animation (scale 1.0↔1.06, ease-in-out) to feel alive and to subtly pace the user's breathing.
- **Circular countdown ring** around or near the mascot: a gradient stroke that depletes over
  `breakSeconds`, with the remaining seconds shown in a rounded font in the center.
- **Rounded typography** (`NSFont.systemFont` with `.rounded` design) for a friendly tone.
- **Encouraging, rotating copy**, e.g.:
  - "Look 20 feet away and blink a few times 👀"
  - "Eyes off the screen — you've earned a breather ✨"
  - "Roll your shoulders and gaze into the distance 🌿"
  - "Quick reset! Soften your focus for a moment 💆"
- **Skip** rendered as a soft pill/capsule button (subtle, lower-prominence than the break
  itself) with hover feedback.
- **Animations:** fade + slight scale-up on appear (~0.35 s ease-out), fade-out on dismiss;
  ring animates smoothly; mascot pulses throughout.
- Respects light/dark appearance via system materials.

**Menu bar**
- SF Symbol eye icon; template-rendered so it adapts to light/dark menu bars.
- Optional subtle state hint (e.g. a slightly different symbol while paused) — nice-to-have.

## Error Handling & Edge Cases

- **Re-entrancy:** scheduler guards against opening a second overlay mid-break.
- **Sleep/wake:** recompute next fire on wake; at most one catch-up break, no burst.
- **Multi-display / hot-plug:** overlay covers all screens; rebuilds on screen-param change.
- **Login item approval pending:** `SMAppService` registration failure is caught; app keeps
  running, menu reflects state, user can retry from the menu.
- **Pause expiry:** when `pausedUntil`/`snoozedUntil` passes, scheduler resumes automatically.
- **Gatekeeper:** ad-hoc `codesign -s -` so the locally built app launches without quarantine
  friction.

## Packaging & Install

- **`build.sh`**: compile all `Sources/EyeBreak/*.swift` with `swiftc` → assemble
  `EyeBreak.app/Contents/{MacOS/EyeBreak, Info.plist, Resources/}` → ad-hoc codesign →
  optional `--install` flag to copy to `/Applications` and `open` it.
- **`Info.plist`**: `LSUIElement = true`, bundle id `com.eyebreak.app`, display name, version,
  minimum system version.
- **`test.sh`**: compile and run the `BreakScheduler` logic tests (pure time math) without
  AppKit.
- **`README.md`**: build, install, usage, uninstall, and how to change settings.

## Testing Strategy

- **TDD on `BreakScheduler` pure logic** (no AppKit dependency): next-fire computation, snooze,
  pause windows, sleep/wake catch-up clamping, interval changes. Run via `test.sh`.
- **Manual smoke test:** "Take Break Now" menu item validates the overlay on all displays
  immediately (no 30-min wait); verify menu toggles, pause/resume, interval/break-length
  changes, login-item registration, fade/pulse/countdown animations, multi-monitor coverage.
- AppKit UI itself is validated manually (limited value in automated AppKit tests for v1).

## File Layout

```
mac_alarm/
  Sources/EyeBreak/
    main.swift              # entry: NSApplication + accessory policy + AppDelegate
    AppDelegate.swift       # wires Config, Scheduler, MenuBar, Overlay, LoginItem
    Config.swift            # UserDefaults-backed settings
    BreakScheduler.swift    # timer + pure time math (TDD core)
    MenuBarController.swift  # NSStatusItem + menu
    OverlayController.swift  # cute full-screen overlay windows
    LoginItem.swift         # SMAppService wrapper
  Tests/
    SchedulerTests.swift    # pure time-math tests
  build.sh
  test.sh
  Info.plist
  README.md
  docs/superpowers/specs/2026-06-07-eyebreak-reminder-design.md
```

## Open Questions

None blocking. Reminder copy and exact color palette are implementation details that can be
tuned during build.
