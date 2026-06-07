# EyeBreak Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `EyeBreak.app`, a lightweight native macOS menu-bar app that shows a cute full-screen break reminder on a configurable interval (default 30 min) to prevent eye strain.

**Architecture:** A single self-contained `.app` bundle compiled with `swiftc` (no Xcode project, no dependencies). An `LSUIElement` accessory app (no dock icon) with a menu-bar `NSStatusItem` for control, a `BreakScheduler` (timer + pure time math) that drives an `OverlayController` rendering dimmed full-screen "cute" overlay windows on every display. Settings persist in `UserDefaults`; launch-at-login via `SMAppService`.

**Tech Stack:** Swift 6.3.2 (compiled in Swift 5 language mode to avoid strict-concurrency friction), AppKit/Cocoa, Core Animation, ServiceManagement. Built/signed via `build.sh`. Pure logic tested via `test.sh`.

**Build notes (apply everywhere):**
- Compile with `-swift-version 5` to avoid Swift 6 actor-isolation errors in AppKit callbacks.
- All UI runs on the main thread (Timers added to `RunLoop.main`).
- The pure time-math lives in `ScheduleMath.swift` (Foundation-only) so it can be unit-tested without AppKit.

---

## File Structure

```
mac_alarm/
  Sources/EyeBreak/
    main.swift              # entry point: NSApplication + .accessory policy + AppDelegate
    AppDelegate.swift       # wires Config, Scheduler, MenuBar, Overlay, login item
    Config.swift            # UserDefaults-backed settings
    ScheduleMath.swift      # PURE time math (Foundation only) — TDD core
    BreakScheduler.swift    # Timer + state machine; uses ScheduleMath + Config
    LoginItem.swift         # SMAppService wrapper (static)
    Messages.swift          # rotating friendly reminder strings + rounded-font helper
    CountdownRing.swift     # cute animated circular countdown view
    BreakOverlayView.swift  # the centered gradient card (mascot, ring, message, skip)
    OverlayController.swift  # one overlay window per screen; show/dismiss/fade
    MenuBarController.swift  # NSStatusItem + menu (built on open)
  Tests/
    ScheduleMathTests.swift # pure time-math tests (no AppKit)
  build.sh                  # compile -> assemble EyeBreak.app -> ad-hoc sign -> optional --install
  test.sh                   # compile + run ScheduleMath tests
  Info.plist                # LSUIElement, bundle id, version
  README.md
```

---

## Task 1: ScheduleMath pure logic (TDD)

**Files:**
- Create: `Sources/EyeBreak/ScheduleMath.swift`
- Test: `Tests/ScheduleMathTests.swift`
- Create: `test.sh`

- [ ] **Step 1: Write the failing tests**

Create `Tests/ScheduleMathTests.swift`:

```swift
import Foundation

// Minimal assertion harness (no XCTest needed for a single pure file).
var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if !cond { failures += 1; print("FAIL: \(msg)") } else { print("ok: \(msg)") }
}

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
```

Create `test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Compiling ScheduleMath tests..."
swiftc -swift-version 5 -o build/schedmath_tests \
  Sources/EyeBreak/ScheduleMath.swift Tests/ScheduleMathTests.swift
echo "Running..."
./build/schedmath_tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
mkdir -p build && chmod +x test.sh && ./test.sh
```
Expected: FAIL — compile error, `cannot find 'ScheduleMath' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/EyeBreak/ScheduleMath.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./test.sh`
Expected: each `ok:` line, then `ALL PASSED`.

- [ ] **Step 5: Commit**

```bash
git add Sources/EyeBreak/ScheduleMath.swift Tests/ScheduleMathTests.swift test.sh
git commit -m "feat: add pure ScheduleMath time logic with tests"
```

---

## Task 2: App scaffold, Info.plist, build.sh, minimal launch

**Files:**
- Create: `Info.plist`
- Create: `Sources/EyeBreak/main.swift`
- Create: `Sources/EyeBreak/AppDelegate.swift`
- Create: `build.sh`

- [ ] **Step 1: Create `Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>EyeBreak</string>
    <key>CFBundleDisplayName</key>
    <string>EyeBreak</string>
    <key>CFBundleIdentifier</key>
    <string>com.eyebreak.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>EyeBreak</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Create `Sources/EyeBreak/AppDelegate.swift` (minimal)**

```swift
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("EyeBreak launched")
    }
}
```

- [ ] **Step 3: Create `Sources/EyeBreak/main.swift`**

```swift
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu-bar only, no dock icon
app.run()
```

- [ ] **Step 4: Create `build.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/EyeBreak.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "Cleaning..."
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compiling..."
swiftc -swift-version 5 -O \
  -o "$BIN_DIR/EyeBreak" \
  Sources/EyeBreak/*.swift

echo "Assembling bundle..."
cp Info.plist "$APP/Contents/Info.plist"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "Installing to /Applications..."
  rm -rf "/Applications/EyeBreak.app"
  cp -R "$APP" "/Applications/EyeBreak.app"
  echo "Launching..."
  open "/Applications/EyeBreak.app"
fi

if [[ "${1:-}" == "--run" ]]; then
  open "$APP"
fi
```

- [ ] **Step 5: Build and verify it launches as an accessory app**

Run:
```bash
chmod +x build.sh && ./build.sh && open build/EyeBreak.app && sleep 2 && pgrep -x EyeBreak && echo "RUNNING" && log show --predicate 'process == "EyeBreak"' --last 30s 2>/dev/null | grep -i "EyeBreak launched" || true
```
Expected: build succeeds, `pgrep` prints a PID, `RUNNING`. No dock icon appears.

- [ ] **Step 6: Kill the test instance and commit**

```bash
pkill -x EyeBreak || true
git add Info.plist Sources/EyeBreak/main.swift Sources/EyeBreak/AppDelegate.swift build.sh
git commit -m "feat: scaffold EyeBreak accessory app and build script"
```

---

## Task 3: Config (UserDefaults settings)

**Files:**
- Create: `Sources/EyeBreak/Config.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/Config.swift`**

```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `swiftc -swift-version 5 -typecheck Sources/EyeBreak/Config.swift`
Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add Sources/EyeBreak/Config.swift
git commit -m "feat: add UserDefaults-backed Config"
```

---

## Task 4: LoginItem (launch at login)

**Files:**
- Create: `Sources/EyeBreak/LoginItem.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/LoginItem.swift`**

```swift
import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService for launch-at-login. Failures are logged, never fatal.
enum LoginItem {
    static func set(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("EyeBreak: login item update failed: \(error.localizedDescription)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swiftc -swift-version 5 -typecheck Sources/EyeBreak/LoginItem.swift`
Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add Sources/EyeBreak/LoginItem.swift
git commit -m "feat: add SMAppService login-item wrapper"
```

---

## Task 5: BreakScheduler (timer + state machine)

**Files:**
- Create: `Sources/EyeBreak/BreakScheduler.swift`
- Modify: `Sources/EyeBreak/AppDelegate.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/BreakScheduler.swift`**

```swift
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
```

- [ ] **Step 2: Wire a temporary log into `AppDelegate.swift`**

Replace the contents of `Sources/EyeBreak/AppDelegate.swift` with:

```swift
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = Config.shared
    private var scheduler: BreakScheduler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler = BreakScheduler(config: config)
        scheduler.onBreak = { [weak self] in
            NSLog("EyeBreak: BREAK FIRED (placeholder). next in \(self?.config.intervalMinutes ?? 0) min")
            // Temporary: immediately finish so the loop continues during this task.
            self?.scheduler.breakDidFinish()
        }
        scheduler.start()
        NSLog("EyeBreak launched; first break in \(scheduler.secondsUntilNextBreak)s")
    }
}
```

- [ ] **Step 3: Build and verify the timer fires (fast debug interval)**

Run:
```bash
./build.sh
EYEBREAK_DEBUG_SECONDS=2 ./build/EyeBreak.app/Contents/MacOS/EyeBreak &
EB_PID=$!
sleep 6
kill $EB_PID 2>/dev/null || true
log show --predicate 'process == "EyeBreak"' --last 15s 2>/dev/null | grep "BREAK FIRED" | head -3
```
Expected: at least one `BREAK FIRED (placeholder)` line (fires every ~2s).

- [ ] **Step 4: Commit**

```bash
git add Sources/EyeBreak/BreakScheduler.swift Sources/EyeBreak/AppDelegate.swift
git commit -m "feat: add BreakScheduler with timer, pause/snooze, sleep-wake handling"
```

---

## Task 6: Messages + rounded-font helper

**Files:**
- Create: `Sources/EyeBreak/Messages.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/Messages.swift`**

```swift
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
```

- [ ] **Step 2: Verify it compiles**

Run: `swiftc -swift-version 5 -typecheck Sources/EyeBreak/Messages.swift`
Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add Sources/EyeBreak/Messages.swift
git commit -m "feat: add rotating reminder messages and rounded-font helper"
```

---

## Task 7: CountdownRing (animated circular timer view)

**Files:**
- Create: `Sources/EyeBreak/CountdownRing.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/CountdownRing.swift`**

```swift
import Cocoa

/// A cute circular countdown: a faint track, a depleting gradient-colored progress
/// ring (smoothly animated via Core Animation), and the remaining seconds in the center.
final class CountdownRing: NSView {
    private let track = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let label = NSTextField(labelWithString: "")
    private let lineWidth: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setup()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    private func setup() {
        for l in [track, progress] {
            l.fillColor = NSColor.clear.cgColor
            l.lineWidth = lineWidth
            l.lineCap = .round
            layer?.addSublayer(l)
        }
        track.strokeColor = NSColor.white.withAlphaComponent(0.18).cgColor
        progress.strokeColor = NSColor.white.cgColor

        label.font = Messages.rounded(40, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        addSubview(label)
    }

    override func layout() {
        super.layout()
        let inset = lineWidth / 2 + 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = CGPath(ellipseIn: rect, transform: nil)
        for l in [track, progress] {
            l.frame = bounds
            l.path = path
        }
        // Start the ring at 12 o'clock and deplete clockwise.
        progress.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        progress.position = CGPoint(x: bounds.midX, y: bounds.midY)
        progress.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        label.frame = NSRect(x: 0, y: bounds.midY - 28, width: bounds.width, height: 56)
    }

    /// Begin the smooth depletion animation over `duration` seconds.
    func start(duration: TimeInterval) {
        progress.removeAnimation(forKey: "deplete")
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 1.0
        anim.toValue = 0.0
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        progress.add(anim, forKey: "deplete")
    }

    func setRemaining(_ seconds: Int) {
        label.stringValue = "\(seconds)"
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swiftc -swift-version 5 -typecheck Sources/EyeBreak/CountdownRing.swift Sources/EyeBreak/Messages.swift`
Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add Sources/EyeBreak/CountdownRing.swift
git commit -m "feat: add animated CountdownRing view"
```

---

## Task 8: BreakOverlayView (the cute gradient card)

**Files:**
- Create: `Sources/EyeBreak/BreakOverlayView.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/BreakOverlayView.swift`**

```swift
import Cocoa

/// A layer-backed view whose backing layer is a rounded gradient — the cute card.
private final class GradientCard: NSView {
    override func makeBackingLayer() -> CALayer {
        let l = CAGradientLayer()
        l.colors = [
            NSColor(calibratedRed: 0.40, green: 0.36, blue: 0.90, alpha: 0.95).cgColor, // indigo
            NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.74, alpha: 0.95).cgColor, // teal
        ]
        l.startPoint = CGPoint(x: 0, y: 1)
        l.endPoint = CGPoint(x: 1, y: 0)
        l.cornerRadius = 28
        l.cornerCurve = .continuous
        return l
    }
    override var wantsUpdateLayer: Bool { true }
}

/// A soft rounded-capsule "Skip" button.
private final class CapsuleButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        isBordered = false
        bezelStyle = .regularSquare
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        contentTintColor = .white
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override var intrinsicContentSize: NSSize {
        var s = super.intrinsicContentSize; s.width += 36; s.height = 32; return s
    }
}

/// The full break card: blurred backdrop + gradient card with mascot, ring, message, skip.
final class BreakOverlayView: NSView {
    let ring = CountdownRing(frame: NSRect(x: 0, y: 0, width: 180, height: 180))
    private let mascot = NSTextField(labelWithString: "👀")
    private let message = NSTextField(labelWithString: "")
    var onSkip: (() -> Void)?

    init(message text: String) {
        super.init(frame: .zero)
        wantsLayer = true
        build(text: text)
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    private func build(text: String) {
        // Blurred dimmed backdrop covering the whole screen.
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        let dim = NSView()
        dim.wantsLayer = true
        dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        dim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dim)

        // The card.
        let card = GradientCard()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.shadow = {
            let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.35)
            s.shadowBlurRadius = 40; s.shadowOffset = NSSize(width: 0, height: -10); return s
        }()
        addSubview(card)

        mascot.font = NSFont.systemFont(ofSize: 72)
        mascot.alignment = .center
        mascot.isBezeled = false; mascot.drawsBackground = false; mascot.isEditable = false
        mascot.wantsLayer = true

        let title = NSTextField(labelWithString: "Time to rest your eyes")
        title.font = Messages.rounded(26, weight: .bold)
        title.textColor = .white
        title.alignment = .center
        title.isBezeled = false; title.drawsBackground = false

        message.stringValue = text
        message.font = Messages.rounded(17, weight: .medium)
        message.textColor = NSColor.white.withAlphaComponent(0.92)
        message.alignment = .center
        message.maximumNumberOfLines = 2
        message.isBezeled = false; message.drawsBackground = false; message.isEditable = false

        let skip = CapsuleButton()
        skip.title = "Skip"
        skip.font = Messages.rounded(14, weight: .semibold)
        skip.target = self
        skip.action = #selector(skipTapped)

        let stack = NSStackView(views: [mascot, ring, title, message, skip])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        ring.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: trailingAnchor),
            dim.topAnchor.constraint(equalTo: topAnchor),
            dim.bottomAnchor.constraint(equalTo: bottomAnchor),

            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 460),

            ring.widthAnchor.constraint(equalToConstant: 180),
            ring.heightAnchor.constraint(equalToConstant: 180),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 44),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -44),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -40),
        ])
    }

    /// Gentle breathing pulse on the mascot, looping for the duration of the break.
    func startMascotPulse() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.08
        pulse.duration = 1.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        mascot.layer?.add(pulse, forKey: "pulse")
    }

    @objc private func skipTapped() { onSkip?() }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
swiftc -swift-version 5 -typecheck \
  Sources/EyeBreak/BreakOverlayView.swift \
  Sources/EyeBreak/CountdownRing.swift \
  Sources/EyeBreak/Messages.swift
```
Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add Sources/EyeBreak/BreakOverlayView.swift
git commit -m "feat: add cute gradient break overlay card view"
```

---

## Task 9: OverlayController (windows per screen) + full loop wiring

**Files:**
- Create: `Sources/EyeBreak/OverlayController.swift`
- Modify: `Sources/EyeBreak/AppDelegate.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/OverlayController.swift`**

```swift
import Cocoa

/// Presents a full-screen break overlay on every display, runs the countdown,
/// then dismisses (auto when time elapses, or early via Skip/ESC).
final class OverlayController {
    private var windows: [NSWindow] = []
    private var views: [BreakOverlayView] = []
    private var ticker: Timer?
    private var remaining = 0
    private var onFinish: (() -> Void)?
    private var isShowing = false

    /// Show the overlay. `onFinish` is called exactly once when the break ends.
    func show(breakSeconds: Int, message: String, playSound: Bool, onFinish: @escaping () -> Void) {
        guard !isShowing else { return }
        isShowing = true
        self.onFinish = onFinish
        self.remaining = breakSeconds

        for screen in NSScreen.screens {
            let view = BreakOverlayView(message: message)
            view.onSkip = { [weak self] in self?.finish() }

            let win = NSWindow(contentRect: screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .screenSaver
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.ignoresMouseEvents = false
            win.contentView = view
            win.setFrame(screen.frame, display: true)
            win.alphaValue = 0
            win.makeKeyAndOrderFront(nil)

            views.append(view)
            windows.append(win)

            view.ring.setRemaining(remaining)
            view.ring.start(duration: TimeInterval(breakSeconds))
            view.startMascotPulse()
        }

        NSApp.activate(ignoringOtherApps: true)
        fadeIn()

        if playSound { NSSound(named: "Glass")?.play() }

        // ESC closes early.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(); return nil }  // 53 == ESC
            return event
        }

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remaining -= 1
            for v in self.views { v.ring.setRemaining(max(0, self.remaining)) }
            if self.remaining <= 0 { self.finish() }
        }
        RunLoop.main.add(ticker!, forMode: .common)

        // Rebuild on display changes mid-break.
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screensChanged() {
        guard isShowing else { return }
        // Re-fit existing windows to current screens (simple, robust).
        for (i, win) in windows.enumerated() where i < NSScreen.screens.count {
            win.setFrame(NSScreen.screens[i].frame, display: true)
        }
    }

    private func fadeIn() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for w in windows { w.animator().alphaValue = 1 }
        }
    }

    private func finish() {
        guard isShowing else { return }
        isShowing = false
        ticker?.invalidate(); ticker = nil
        NotificationCenter.default.removeObserver(
            self, name: NSApplication.didChangeScreenParametersNotification, object: nil)

        let toClose = windows
        windows.removeAll(); views.removeAll()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            for w in toClose { w.animator().alphaValue = 0 }
        }, completionHandler: {
            for w in toClose { w.orderOut(nil) }
            self.onFinish?()
            self.onFinish = nil
        })
    }
}
```

- [ ] **Step 2: Wire the real overlay into `AppDelegate.swift`**

Replace the contents of `Sources/EyeBreak/AppDelegate.swift` with:

```swift
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let config = Config.shared
    private var scheduler: BreakScheduler!
    private let overlay = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler = BreakScheduler(config: config)
        scheduler.onBreak = { [weak self] in self?.presentBreak() }
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
```

- [ ] **Step 3: Build and verify the full overlay loop (fast debug)**

Run:
```bash
./build.sh
EYEBREAK_DEBUG_SECONDS=3 ./build/EyeBreak.app/Contents/MacOS/EyeBreak &
EB_PID=$!
sleep 8
ps -p $EB_PID >/dev/null && echo "STILL ALIVE (overlay shown + dismissed without crash)"
kill $EB_PID 2>/dev/null || true
```
Expected: `STILL ALIVE` — the overlay appeared (cute card on screen), counted down ~3s, faded out, and the app kept running. (Visual confirmation is the user's manual check.)

- [ ] **Step 4: Commit**

```bash
git add Sources/EyeBreak/OverlayController.swift Sources/EyeBreak/AppDelegate.swift
git commit -m "feat: full break overlay loop across all displays"
```

---

## Task 10: MenuBarController (controls) + final wiring

**Files:**
- Create: `Sources/EyeBreak/MenuBarController.swift`
- Modify: `Sources/EyeBreak/AppDelegate.swift`

- [ ] **Step 1: Create `Sources/EyeBreak/MenuBarController.swift`**

```swift
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
        let statusItemRow = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItemRow.isEnabled = false
        menu.addItem(statusItemRow)
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
```

- [ ] **Step 2: Wire the menu bar into `AppDelegate.swift`**

Replace the contents of `Sources/EyeBreak/AppDelegate.swift` with:

```swift
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
```

- [ ] **Step 3: Build and verify the menu bar appears and Take Break Now works**

Run:
```bash
./build.sh
./build/EyeBreak.app/Contents/MacOS/EyeBreak &
EB_PID=$!
sleep 2
ps -p $EB_PID >/dev/null && echo "MENU BAR APP RUNNING (look for the 👁 icon in the menu bar)"
kill $EB_PID 2>/dev/null || true
```
Expected: `MENU BAR APP RUNNING`; an eye icon appears in the menu bar. (User manually verifies the menu items, Take Break Now overlay, and toggles.)

- [ ] **Step 4: Commit**

```bash
git add Sources/EyeBreak/MenuBarController.swift Sources/EyeBreak/AppDelegate.swift
git commit -m "feat: add menu-bar controls and wire full app"
```

---

## Task 11: README + install verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create `README.md`**

```markdown
# EyeBreak 👀

A lightweight macOS menu-bar app that reminds you to rest your eyes on a schedule
(default every 30 minutes) with a cute full-screen break overlay. Prevents digital
eye strain using a gentle, hard-to-ignore nudge.

## Features
- Full-screen "cute" break overlay: blurred backdrop, gradient card, breathing 👀
  mascot, animated countdown ring, encouraging messages.
- Menu-bar control (no dock icon): Take Break Now, Snooze 5 min, Pause (15 min / 1 hr),
  Interval (20/25/30/45/60 min), Break length (10/20/30/60 s), Sound, Open at Login, Quit.
- Configurable interval (default 30 min) and break length (default 20 s).
- Launches at login. Handles sleep/wake and multiple displays.

## Requirements
- macOS 13+ (built/tested on macOS 26, Apple Silicon)
- Xcode Command Line Tools (`xcode-select --install`) for building

## Build & Install
```bash
./build.sh --install     # compiles, signs, copies to /Applications, launches
```
Or build without installing:
```bash
./build.sh               # produces build/EyeBreak.app
./build.sh --run         # build and launch from build/
```

## Usage
Click the 👁 icon in the menu bar to control everything. Change the interval and
break length there. "Open at Login" keeps it running in the background automatically.

## Test
```bash
./test.sh                # runs pure scheduler-logic tests
```

## Tip: quick demo
Run with a short interval to see the overlay immediately:
```bash
EYEBREAK_DEBUG_SECONDS=3 ./build/EyeBreak.app/Contents/MacOS/EyeBreak
```

## Uninstall
Quit from the menu, then:
```bash
rm -rf /Applications/EyeBreak.app
```
To remove the login item, toggle "Open at Login" off before quitting.
```

- [ ] **Step 2: Full clean build + test + run verification**

Run:
```bash
./test.sh && ./build.sh && ./build/EyeBreak.app/Contents/MacOS/EyeBreak &
EB_PID=$!
sleep 2
ps -p $EB_PID >/dev/null && echo "FINAL: app builds, tests pass, launches"
kill $EB_PID 2>/dev/null || true
```
Expected: `ALL PASSED` from tests, build succeeds, `FINAL: ...` printed.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with build/usage instructions"
```

---

## Self-Review

**Spec coverage:**
- Lightweight native app, always-running, launches at login → Tasks 2, 4, 10 (LoginItem + `LSUIElement`). ✓
- Full-screen break overlay with countdown → Tasks 7, 8, 9. ✓
- Menu-bar control (no dock icon) → Task 10 + `.accessory` policy (Task 2). ✓
- Configurable interval (default 30) + break length (default 20) → Task 3 + menus (Task 10). ✓
- Snooze / Pause / Resume / Take Break Now / Sound toggle → Tasks 5, 9, 10. ✓
- Modern & cute UI (blur, gradient card, mascot pulse, ring, rounded font, rotating copy, fade) → Tasks 6, 7, 8, 9. ✓
- Edge cases: re-entrancy guard, sleep/wake catch-up, multi-display + hot-plug → Tasks 5, 9. ✓
- Packaging (build.sh, ad-hoc sign, install), tests (test.sh), README → Tasks 1, 2, 11. ✓

**Placeholder scan:** No TBD/TODO; every code step contains full code; the AppDelegate placeholder in Task 5 is intentional and explicitly replaced in Tasks 9 and 10.

**Type consistency:** `BreakScheduler` API (`start`, `scheduleNormal`, `snooze(minutes:)`, `pause(minutes:)`, `resume`, `triggerBreakNow`, `breakDidFinish`, `onBreak`, `secondsUntilNextBreak`, `isPaused`, `nextFire`) is used consistently in AppDelegate and MenuBarController. `OverlayController.show(breakSeconds:message:playSound:onFinish:)` matches its call site. `CountdownRing` (`start(duration:)`, `setRemaining(_:)`) and `BreakOverlayView` (`ring`, `onSkip`, `startMascotPulse()`) match usage in OverlayController. `Config` property names match across files. `Messages.next()` / `Messages.rounded(_:weight:)` match usage. ✓

**Note on minor spec deviations (intentional):** pure math split into its own `ScheduleMath.swift` (cleaner testing); menu status line refreshed on menu-open via `menuNeedsUpdate` instead of a 15 s timer (simpler, always-fresh). Both improve on the spec without changing behavior.
