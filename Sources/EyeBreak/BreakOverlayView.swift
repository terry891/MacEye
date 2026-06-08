import Cocoa

/// The cute center card: a rounded gradient. The gradient lives in a masked sublayer
/// (so the rounded corners actually clip the gradient), inside a container backing layer
/// that carries the drop shadow (masking would otherwise clip the shadow away).
private final class GradientCard: NSView {
    private let gradient = CAGradientLayer()
    private let cornerRadius: CGFloat = 40

    override func makeBackingLayer() -> CALayer {
        gradient.colors = [
            NSColor(srgbRed: 0.40, green: 0.36, blue: 0.90, alpha: 0.97).cgColor, // indigo
            NSColor(srgbRed: 0.20, green: 0.70, blue: 0.74, alpha: 0.97).cgColor, // teal
        ]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.cornerRadius = cornerRadius
        gradient.cornerCurve = .continuous
        gradient.masksToBounds = true   // <- actually rounds the gradient fill

        let container = CALayer()
        container.masksToBounds = false  // <- lets the shadow render outside the corners
        container.addSublayer(gradient)
        return container
    }

    override var wantsUpdateLayer: Bool { true }

    override func layout() {
        super.layout()
        gradient.frame = bounds
        // Match the shadow to the rounded shape for a crisp soft shadow.
        layer?.shadowPath = CGPath(roundedRect: bounds,
                                   cornerWidth: cornerRadius,
                                   cornerHeight: cornerRadius,
                                   transform: nil)
    }
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

    // The mascot cross-fades through these eye-related emojis during a break.
    private let eyeEmojis = ["👀", "👁️", "👁️‍🗨️", "🧿", "🪬", "🕶️", "😎", "🥽"]
    private var emojiIndex = 0
    private var emojiTimer: Timer?

    // Twinkling colorful star/sparkle layer scattered across the blurred backdrop.
    private let sparkleHost = NSView()
    private var builtSparkles = false

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
        dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.30).cgColor
        dim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dim)

        // Twinkling sparkles live above the dim, behind the card.
        sparkleHost.wantsLayer = true
        sparkleHost.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sparkleHost)

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
            sparkleHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            sparkleHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            sparkleHost.topAnchor.constraint(equalTo: topAnchor),
            sparkleHost.bottomAnchor.constraint(equalTo: bottomAnchor),

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

    override func layout() {
        super.layout()
        // Build the starfield once, when we first know the screen size.
        if !builtSparkles, bounds.width > 1, bounds.height > 1 {
            builtSparkles = true
            buildSparkles(in: bounds)
        }
    }

    private func buildSparkles(in rect: CGRect) {
        guard let host = sparkleHost.layer else { return }
        let palette: [NSColor] = [
            NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1), // white
            NSColor(srgbRed: 1.00, green: 0.85, blue: 0.42, alpha: 1), // gold
            NSColor(srgbRed: 0.52, green: 0.90, blue: 1.00, alpha: 1), // cyan
            NSColor(srgbRed: 1.00, green: 0.62, blue: 0.82, alpha: 1), // pink
            NSColor(srgbRed: 0.62, green: 1.00, blue: 0.82, alpha: 1), // mint
            NSColor(srgbRed: 0.80, green: 0.72, blue: 1.00, alpha: 1), // lavender
        ]
        let count = min(90, max(40, Int((rect.width * rect.height) / 52000)))
        for _ in 0..<count {
            let color = palette.randomElement() ?? .white
            let isStar = Double.random(in: 0...1) < 0.30
            let layer = isStar
                ? makeStarLayer(color: color, size: .random(in: 9...17))
                : makeDotLayer(color: color, size: .random(in: 3...8))
            layer.position = CGPoint(x: .random(in: 0...rect.width),
                                     y: .random(in: 0...rect.height))
            host.addSublayer(layer)
            addTwinkle(to: layer)
        }
    }

    /// A soft glowing dot (radial gradient) for a "star".
    private func makeDotLayer(color: NSColor, size: CGFloat) -> CALayer {
        let glow = size * 2.6
        let l = CAGradientLayer()
        l.type = .radial
        l.colors = [color.withAlphaComponent(0.95).cgColor, color.withAlphaComponent(0.0).cgColor]
        l.locations = [0.0, 1.0]
        l.startPoint = CGPoint(x: 0.5, y: 0.5)
        l.endPoint = CGPoint(x: 1.0, y: 1.0)
        l.bounds = CGRect(x: 0, y: 0, width: glow, height: glow)
        return l
    }

    /// A small 4-point sparkle with a colored glow.
    private func makeStarLayer(color: NSColor, size: CGFloat) -> CALayer {
        let s = CAShapeLayer()
        let r = size / 2, k = size * 0.15, c = CGPoint(x: r, y: r)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y + r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
        p.closeSubpath()
        s.path = p
        s.fillColor = color.cgColor
        s.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        s.shadowColor = color.cgColor
        s.shadowRadius = size * 0.45
        s.shadowOpacity = 0.85
        s.shadowOffset = .zero
        return s
    }

    /// Independent blink (opacity) + gentle scale, each sparkle on its own phase.
    private func addTwinkle(to layer: CALayer) {
        let dur = Double.random(in: 1.2...3.0)
        let off = Double.random(in: 0...3.0)
        layer.opacity = Float.random(in: 0.2...0.6)

        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = Float.random(in: 0.05...0.20)
        blink.toValue = Float.random(in: 0.75...1.0)
        blink.duration = dur
        blink.autoreverses = true
        blink.repeatCount = .infinity
        blink.timeOffset = off
        blink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(blink, forKey: "blink")

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = CGFloat.random(in: 0.4...0.7)
        scale.toValue = 1.0
        scale.duration = dur * 1.1
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timeOffset = off
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(scale, forKey: "twinkleScale")
    }

    /// Begin cross-fading the mascot through the eye emojis.
    func startEmojiCycle() {
        emojiTimer?.invalidate()
        let t = Timer(timeInterval: 2.2, repeats: true) { [weak self] _ in
            self?.advanceEmoji()
        }
        RunLoop.main.add(t, forMode: .common)
        emojiTimer = t
    }

    private func advanceEmoji() {
        emojiIndex = (emojiIndex + 1) % eyeEmojis.count
        let fade = CATransition()
        fade.type = .fade
        fade.duration = 0.55
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        mascot.layer?.add(fade, forKey: "emojiFade")
        mascot.stringValue = eyeEmojis[emojiIndex]
    }

    /// Stop timers/animations when the overlay is dismissed.
    func stop() {
        emojiTimer?.invalidate()
        emojiTimer = nil
    }

    @objc private func skipTapped() { onSkip?() }
}
