import AppKit
import Carbon.HIToolbox

/// Injects text into the currently focused input by using the system clipboard
/// and simulating ⌘V, with CJK input source detection and temporary switching.
final class TextInjector {

    func inject(text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard content
        let savedString = pasteboard.string(forType: .string)
        let savedRTF    = pasteboard.data(forType: .rtf)
        let savedTypes  = pasteboard.types ?? []

        // 2. Detect current input source
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let needsSwitch   = isNonASCII(source: currentSource)

        // 3. Temporarily switch to an ASCII input source if needed
        if needsSwitch {
            switchToASCII()
            // Small delay to let the input source activate
            Thread.sleep(forTimeInterval: 0.05)
        }

        // 4. Write our text to the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 5. Simulate ⌘V
        Thread.sleep(forTimeInterval: 0.03)
        postCmdV()

        // 6. After paste settles: restore input source and clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if needsSwitch {
                TISSelectInputSource(currentSource)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                pasteboard.clearContents()
                if let s = savedString {
                    pasteboard.setString(s, forType: .string)
                } else if let rtf = savedRTF {
                    pasteboard.setData(rtf, forType: .rtf)
                }
                // If clipboard was empty or had some other type, we leave it clear.
                _ = savedTypes // suppress warning
            }
        }
    }

    // MARK: - Helpers

    private func isNonASCII(source: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return false
        }
        // The property is a retained CFArray of language strings.
        let cfArray = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue()
        let languages = cfArray as NSArray as? [String] ?? []
        return languages.contains { lang in
            lang.hasPrefix("zh") || lang.hasPrefix("ja") || lang.hasPrefix("ko")
        }
    }

    private func switchToASCII() {
        let filter: [String: Any] = [
            kTISPropertyInputSourceIsASCIICapable as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        guard let listRef = TISCreateInputSourceList(filter as CFDictionary, false) else { return }
        let list = listRef.takeRetainedValue() as NSArray as? [TISInputSource] ?? []
        if let ascii = list.first {
            TISSelectInputSource(ascii)
        }
    }

    private func postCmdV() {
        // Virtual key code 9 = 'v'
        let src   = CGEventSource(stateID: .combinedSessionState)
        let down  = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up    = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
