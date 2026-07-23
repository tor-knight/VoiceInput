import AppKit
import AVFoundation
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager!
    private var fnKeyMonitor: FnKeyMonitor!
    private var voiceRecorder: VoiceRecorder!
    private var floatingWindowController: FloatingWindowController!
    private var textInjector: TextInjector!
    private var llmRefiner: LLMRefiner!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        requestPermissions()

        textInjector             = TextInjector()
        llmRefiner               = LLMRefiner()
        voiceRecorder            = VoiceRecorder()
        floatingWindowController = FloatingWindowController()
        statusBarManager         = StatusBarManager()

        setupVoiceRecorderCallbacks()

        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor.onFnDown = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            DispatchQueue.main.async { self?.stopRecording() }
        }
        fnKeyMonitor.start()
    }

    // MARK: - Permission requests

        private func setupMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "Quit VoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Edit Menu (Required for Copy/Paste shortcuts)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: Selector(("cut:")), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: Selector(("copy:")), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: Selector(("paste:")), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a"))
    }

    private func requestPermissions() {
        // Microphone
        AVCaptureDevice.requestAccess(for: .audio) { _ in }

        // Speech recognition
        SFSpeechRecognizer.requestAuthorization { _ in }

        // Accessibility (for CGEvent tap and keyboard simulation)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Callbacks

    private func setupVoiceRecorderCallbacks() {
        voiceRecorder.onTranscription = { [weak self] text in
            DispatchQueue.main.async {
                self?.floatingWindowController.updateText(text)
            }
        }
        voiceRecorder.onRMSUpdate = { [weak self] rms in
            DispatchQueue.main.async {
                self?.floatingWindowController.updateRMS(rms)
            }
        }
    }

    // MARK: - Recording lifecycle

    private func startRecording() {
        floatingWindowController.show()
        voiceRecorder.startRecording(locale: Locale(identifier: Preferences.selectedLanguage.rawValue))
    }

    private func stopRecording() {
        voiceRecorder.stopRecording { [weak self] finalText, duration in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !finalText.isEmpty else {
                    self.floatingWindowController.hide()
                    return
                }
                                let requiresKey = (Preferences.llmProvider != .ollama && Preferences.llmProvider != .custom)
                let hasKey = !Preferences.llmAPIKey.isEmpty
                let canCallLLM = Preferences.llmEnabled && (!requiresKey || hasKey)

                let charCount = finalText.count
                let estimatedTokens = Int(Double(charCount) * 1.5)

                logDebug("stopRecording - text: '\(finalText)' | llmEnabled: \(Preferences.llmEnabled) | provider: \(Preferences.llmProvider.rawValue) | canCallLLM: \(canCallLLM)")

                if canCallLLM {
                    self.floatingWindowController.showRefining()
                    self.llmRefiner.refine(text: finalText) { refined in
                        DispatchQueue.main.async {
                            self.floatingWindowController.hide()
                            self.textInjector.inject(text: refined)

                            DatabaseManager.shared.insertLog(
                                id: UUID().uuidString,
                                createdAt: Date(),
                                durationMs: duration * 1000,
                                charCount: charCount,
                                estimatedTokens: estimatedTokens,
                                originalText: finalText,
                                refinedText: refined,
                                modelUsed: Preferences.llmModel
                            )
                            SyncService.shared.syncIfNeeded()
                        }
                    }
                } else {
                    self.floatingWindowController.hide()
                    self.textInjector.inject(text: finalText)

                    DatabaseManager.shared.insertLog(
                        id: UUID().uuidString,
                        createdAt: Date(),
                        durationMs: duration * 1000,
                        charCount: charCount,
                        estimatedTokens: estimatedTokens,
                        originalText: finalText,
                        refinedText: finalText,
                        modelUsed: "None"
                    )
                    SyncService.shared.syncIfNeeded()
                }
            }
        }
    }
}
