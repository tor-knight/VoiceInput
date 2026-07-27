import CoreGraphics
import Foundation

/// Monitors the global Fn key via a CGEvent tap.
/// Suppresses Fn events so they never reach the system emoji picker.
public final class FnKeyMonitor {
    public var onFnDown: (() -> Void)?
    public var onFnUp:   (() -> Void)?

    /// Delay threshold (in seconds) required for press-and-hold to trigger voice input.
    /// Default is 0.5s (500ms). Quick taps (< 0.5s) are ignored so input method switching works.
    public var holdDelay: TimeInterval = 0.5

    // internal so the C callback shim (same file) can reach eventTap for re-enable
    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false
    private var isRecordingStarted = false
    private var holdWorkItem: DispatchWorkItem?

    // We keep a pointer to self alive for the C callback lifetime.
    // Since FnKeyMonitor lives for the entire app session this is fine.
    private var retainedSelf: Unmanaged<FnKeyMonitor>?

    public init() {}

    public func start() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        retainedSelf = Unmanaged.passRetained(self)
        let ptr = retainedSelf!.toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // active tap so we can suppress events
            eventsOfInterest: mask,
            callback: fnKeyCallback,
            userInfo: ptr
        ) else {
            retainedSelf?.release()
            retainedSelf = nil
            print("[VoiceInput] Failed to create CGEvent tap — grant Accessibility permission in System Settings.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        retainedSelf?.release()
        retainedSelf = nil
    }

    // Called from the C callback shim below.
    @discardableResult
    public func handleFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 63 else {
            // Not the Fn key; pass through unchanged.
            return Unmanaged.passUnretained(event)
        }

        let fnPressed = event.flags.contains(.maskSecondaryFn)

        if fnPressed && !isFnDown {
            isFnDown = true
            isRecordingStarted = false

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isFnDown else { return }
                self.isRecordingStarted = true
                self.onFnDown?()
            }
            self.holdWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: workItem)

            // Return nil to swallow event during key down
            return nil
        } else if !fnPressed && isFnDown {
            isFnDown = false
            holdWorkItem?.cancel()
            holdWorkItem = nil

            if isRecordingStarted {
                isRecordingStarted = false
                onFnUp?()
                return nil
            } else {
                // Was a short tap (less than holdDelay).
                // Re-post synthetic Fn key press & release to system so native features (like switching input method) still work.
                DispatchQueue.main.async {
                    let src = CGEventSource(stateID: .hidSystemState)
                    if let evDown = CGEvent(keyboardEventSource: src, virtualKey: 63, keyDown: true) {
                        evDown.flags = .maskSecondaryFn
                        evDown.post(tap: .cghidEventTap)
                    }
                    if let evUp = CGEvent(keyboardEventSource: src, virtualKey: 63, keyDown: false) {
                        evUp.flags = []
                        evUp.post(tap: .cghidEventTap)
                    }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}

// MARK: - C-compatible callback shim

/// Top-level C function required by CGEvent.tapCreate.
private func fnKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .flagsChanged:
        return monitor.handleFlagsChanged(event: event)
    case .tapDisabledByTimeout:
        // Re-enable tap if the system disabled it.
        if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return nil
    default:
        return Unmanaged.passUnretained(event)
    }
}
