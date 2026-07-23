import AppKit

/// Elegant translucent capsule HUD shown while recording / refining.
final class FloatingWindowController {

    // MARK: - Constants

    private let windowH:    CGFloat = 56
    private let cornerR:    CGFloat = 28
    private let waveW:      CGFloat = 44
    private let waveH:      CGFloat = 32
    private let padH:       CGFloat = 16   // horizontal edge padding
    private let gapWLabel:  CGFloat = 10   // gap between waveform and label
    private let labelMinW:  CGFloat = 160
    private let labelMaxW:  CGFloat = 560

    // MARK: - Views

    private let panel:            NSPanel
    private let effectView:       NSVisualEffectView
    private let waveformView:     WaveformView
    private let textLabel:        NSTextField
    private let timeLabel:        NSTextField
    private var isVisible         = false
    private var recordTimer:      Timer?
    private var recordStartTime:  Date?
    private var labelWidthConstraint: NSLayoutConstraint!

    // MARK: - Init

    init() {
        // --- Panel ---
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 56),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.isFloatingPanel      = true
        panel.level                = .floating
        panel.backgroundColor      = .clear
        panel.isOpaque             = false
        panel.hasShadow            = false // Turn off default window shadow to prevent sharp corner artifacts
        panel.collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable            = false
        panel.isMovableByWindowBackground = false

        // --- Visual effect backdrop (the capsule) ---
        effectView = NSVisualEffectView()
        effectView.material       = .hudWindow
        effectView.blendingMode   = .behindWindow
        effectView.state          = .active
        effectView.wantsLayer     = true
        effectView.layer?.cornerRadius  = cornerR
        // MUST be false to allow shadow to bleed out of the bounds
        effectView.layer?.masksToBounds = false
        
        // Add smooth shadow to the effect view itself
        effectView.layer?.shadowColor   = NSColor.black.cgColor
        effectView.layer?.shadowOpacity = 0.2
        effectView.layer?.shadowRadius  = 12
        effectView.layer?.shadowOffset  = CGSize(width: 0, height: -4)
        panel.contentView = effectView

        // --- Waveform bars ---
        waveformView = WaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(waveformView)

        // --- Timer label ---
        timeLabel = NSTextField(labelWithString: "00:00")
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.textColor             = NSColor(white: 1.0, alpha: 0.7)
        timeLabel.font                  = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        effectView.addSubview(timeLabel)

        // --- Text label ---
        textLabel = NSTextField(labelWithString: "")
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textColor             = NSColor.white
        textLabel.font                  = NSFont.systemFont(ofSize: 15, weight: .medium)
        textLabel.lineBreakMode         = .byTruncatingHead // Shows newest text on the right
        textLabel.maximumNumberOfLines  = 1
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        effectView.addSubview(textLabel)

        // --- Auto Layout ---
        labelWidthConstraint = textLabel.widthAnchor.constraint(equalToConstant: labelMinW)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: padH),
            waveformView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: waveW),
            waveformView.heightAnchor.constraint(equalToConstant: waveH),

            textLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: gapWLabel),
            textLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            labelWidthConstraint,

            timeLabel.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: gapWLabel),
            timeLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -padH)
        ])

        // Layer-backed for CASpringAnimation on show/hide
        effectView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    // MARK: - Show / Hide

    func show() {
        guard !isVisible else { return }
        isVisible = true
        
        recordStartTime = Date()
        timeLabel.stringValue = "00:00"
        recordTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }

        waveformView.startAnimating()
        updatePanelFrame(labelWidth: labelMinW, animated: false)

        // Set initial state for entry animation
        panel.alphaValue = 0
        effectView.layer?.transform = CATransform3DMakeScale(0.80, 0.80, 1)
        panel.orderFront(nil)

        // Spring scale-in
        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue       = CATransform3DMakeScale(0.80, 0.80, 1)
        spring.toValue         = CATransform3DIdentity
        spring.duration        = 0.45
        spring.damping         = 14
        spring.initialVelocity = 2
        spring.mass            = 0.6
        spring.isRemovedOnCompletion = false
        spring.fillMode              = .forwards
        effectView.layer?.add(spring, forKey: "springIn")
        effectView.layer?.transform = CATransform3DIdentity

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        waveformView.stopAnimating()
        recordTimer?.invalidate()
        recordTimer = nil

        // Scale-out + fade-out
        let scaleOut = CABasicAnimation(keyPath: "transform")
        scaleOut.fromValue = CATransform3DIdentity
        scaleOut.toValue   = CATransform3DMakeScale(0.82, 0.82, 1)
        scaleOut.duration  = 0.22
        scaleOut.timingFunction = CAMediaTimingFunction(name: .easeIn)
        scaleOut.isRemovedOnCompletion = false
        scaleOut.fillMode              = .forwards
        effectView.layer?.add(scaleOut, forKey: "scaleOut")

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.textLabel.stringValue = ""
            // Reset transform for next show
            self.effectView.layer?.transform = CATransform3DIdentity
        })
    }

    // MARK: - Updates

    func updateText(_ text: String) {
        textLabel.stringValue = text
        let desired = desiredLabelWidth(for: text)
        animateLabelWidth(to: desired)
    }

    func updateRMS(_ rms: Float) {
        waveformView.rmsLevel = rms
    }

    func showRefining() {
        textLabel.stringValue = "Refining..."
        let desired = desiredLabelWidth(for: "Refining...")
        animateLabelWidth(to: desired)
    }

    // MARK: - Private helpers

    private func desiredLabelWidth(for text: String) -> CGFloat {
        guard !text.isEmpty else { return labelMinW }
        let attrs: [NSAttributedString.Key: Any] = [.font: textLabel.font as Any]
        let measured = (text as NSString).size(withAttributes: attrs).width
        return max(labelMinW, min(labelMaxW, measured + 8))
    }

    private func animateLabelWidth(to width: CGFloat) {
        guard abs(labelWidthConstraint.constant - width) > 1 else { return }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration        = 0.25
            ctx.timingFunction  = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            labelWidthConstraint.animator().constant = width
            updatePanelFrame(labelWidth: width, animated: true)
        }
    }

    private func updateTimer() {
        guard let start = recordStartTime else { return }
        let diff = Int(Date().timeIntervalSince(start))
        let m = diff / 60
        let s = diff % 60
        timeLabel.stringValue = String(format: "%02d:%02d", m, s)
    }

    private func updatePanelFrame(labelWidth: CGFloat, animated: Bool) {
        let timerW: CGFloat = 44
        let totalW = padH + waveW + gapWLabel + labelWidth + gapWLabel + timerW + padH
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x  = sf.midX - totalW / 2
        let y  = sf.minY + 36

        let newFrame = NSRect(x: x, y: y, width: totalW, height: windowH)
        if animated {
            panel.animator().setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: false)
        }
    }
}
