import CoreGraphics
import Foundation
import VoiceInputCore

class FnKeyMonitorTests {
    private func createFnEvent(keyDown: Bool) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 63, keyDown: keyDown)!
        if keyDown {
            event.flags = [.maskSecondaryFn]
        } else {
            event.flags = []
        }
        return event
    }

    func runAllTests() {
        print("Running FnKeyMonitorTests...")
        testQuickTapDoesNotTriggerRecording()
        testPressAndHoldTriggersRecording()
        print("✅ FnKeyMonitorTests passed.")
    }

    func testQuickTapDoesNotTriggerRecording() {
        let monitor = FnKeyMonitor()
        monitor.holdDelay = 0.2 // Short delay for test

        var fnDownCalled = false
        var fnUpCalled = false

        monitor.onFnDown = { fnDownCalled = true }
        monitor.onFnUp = { fnUpCalled = true }

        let downEvent = createFnEvent(keyDown: true)
        _ = monitor.handleFlagsChanged(event: downEvent)

        // Release before holdDelay (0.05s < 0.2s)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        let upEvent = createFnEvent(keyDown: false)
        _ = monitor.handleFlagsChanged(event: upEvent)

        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        assertEquals(fnDownCalled, false, "Quick tap should not trigger onFnDown")
        assertEquals(fnUpCalled, false, "Quick tap should not trigger onFnUp")
    }

    func testPressAndHoldTriggersRecording() {
        let monitor = FnKeyMonitor()
        monitor.holdDelay = 0.1 // Short delay for test

        var fnDownCalled = false
        var fnUpCalled = false

        monitor.onFnDown = { fnDownCalled = true }
        monitor.onFnUp = { fnUpCalled = true }

        let downEvent = createFnEvent(keyDown: true)
        _ = monitor.handleFlagsChanged(event: downEvent)

        // Run runloop to allow main queue asyncAfter (0.15s > 0.1s) to execute
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        assertEquals(fnDownCalled, true, "onFnDown should be called after hold delay")

        let upEvent = createFnEvent(keyDown: false)
        _ = monitor.handleFlagsChanged(event: upEvent)

        assertEquals(fnUpCalled, true, "onFnUp should be called after key release following a valid hold")
    }
}
