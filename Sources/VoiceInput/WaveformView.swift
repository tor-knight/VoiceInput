import AppKit

/// Five-bar waveform driven by real-time audio RMS levels.
final class WaveformView: NSView {
    /// Set this from the audio callback (any thread); the animation timer reads it.
    var rmsLevel: Float = 0

    // Bar weights: centre is tallest, tapers to sides
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var smoothed: [Float]  = [0, 0, 0, 0, 0]
    private var timer: Timer?

    // Layout constants
    private let barW:      CGFloat = 4.5
    private let gap:       CGFloat = 3.5
    private let maxH:      CGFloat = 27
    private let minH:      CGFloat = 4
    private let cornerR:   CGFloat = 2.25

    // MARK: - Lifecycle

    func startAnimating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil

        // Animate bars to zero over a few frames
        smoothed = [0, 0, 0, 0, 0]
        needsDisplay = true
    }

    // MARK: - Animation tick

    private func tick() {
        // Amplify raw RMS to a 0-1 "loudness" value; loud speech ≈ 0.05–0.3 raw RMS
        let amplified = min(1.0, rmsLevel * 12.0)

        for i in 0..<5 {
            let target = amplified * weights[i]
            // Attack faster than release for snappy feel
            let alpha: Float = target > smoothed[i] ? 0.40 : 0.15
            var next = smoothed[i] + (target - smoothed[i]) * alpha
            // ±4 % organic jitter
            next *= (1.0 + Float.random(in: -0.04...0.04))
            smoothed[i] = max(0, next)
        }

        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let totalW = CGFloat(5) * barW + CGFloat(4) * gap
        let originX = (bounds.width - totalW) / 2.0

        NSColor.white.withAlphaComponent(0.88).setFill()

        for i in 0..<5 {
            let level  = CGFloat(smoothed[i])
            let height = minH + level * (maxH - minH)
            let x      = originX + CGFloat(i) * (barW + gap)
            let y      = (bounds.height - height) / 2.0

            let rect = NSRect(x: x, y: y, width: barW, height: height)
            NSBezierPath(roundedRect: rect, xRadius: cornerR, yRadius: cornerR).fill()
        }
    }
}
