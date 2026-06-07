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
