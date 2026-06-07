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
