import AppKit

// NSApplicationMain behaviour without the attribute:
// Instantiate the delegate on the main thread, hand it to NSApp, then run.
let app = NSApplication.shared
// AppDelegate is an NSObject subclass; constructing it here on the main thread is fine.
let delegate = AppDelegate()
app.delegate = delegate
app.run()
