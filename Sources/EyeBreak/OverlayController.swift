import Cocoa

/// Presents a full-screen break overlay on every display, runs the countdown,
/// then dismisses (auto when time elapses, or early via Skip/ESC).
final class OverlayController {
    private var windows: [NSWindow] = []
    private var views: [BreakOverlayView] = []
    private var ticker: Timer?
    private var escMonitor: Any?
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
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
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
