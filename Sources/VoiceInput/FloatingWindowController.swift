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
    private var isVisible         = false
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
        panel.hasShadow            = true
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
        effectView.layer?.masksToBounds = true
        panel.contentView = effectView

        // --- Waveform bars ---
        waveformView = WaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(waveformView)

        // --- Text label ---
        textLabel = NSTextField(labelWithString: "")
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textColor             = NSColor.white
        textLabel.font                  = NSFont.systemFont(ofSize: 15, weight: .medium)
        textLabel.lineBreakMode         = .byTruncatingTail
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
        ])

        // Layer-backed for CASpringAnimation on show/hide
        effectView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    // MARK: - Show / Hide

    func show() {
        guard !isVisible else { return }
        isVisible = true

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

    private func updatePanelFrame(labelWidth: CGFloat, animated: Bool) {
        let totalW = padH + waveW + gapWLabel + labelWidth + padH
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
