import AppKit

/// Owns the NSStatusItem and its menu.
final class StatusBarManager {
    private var statusItem: NSStatusItem!
    private var settingsController: SettingsWindowController?
    private var statsController: StatisticsWindowController?

    // Menu items that need dynamic state
    private var languageMenuItems: [NSMenuItem] = []
    private var llmEnableItem:     NSMenuItem!

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")
            btn.image?.isTemplate = true
        }
        buildMenu()
    }

    // MARK: - Menu construction

    private func buildMenu() {
        let menu = NSMenu()

        // ── Language ────────────────────────────────────────────────────────
        let langParent = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let langMenu   = NSMenu()
        for lang in Preferences.Language.allCases {
            let item = NSMenuItem(title: lang.displayName,
                                  action: #selector(selectLanguage(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = (lang == Preferences.selectedLanguage) ? .on : .off
            langMenu.addItem(item)
            languageMenuItems.append(item)
        }
        langParent.submenu = langMenu
        menu.addItem(langParent)

        menu.addItem(.separator())

        // ── LLM Refinement ──────────────────────────────────────────────────
        let llmParent = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu   = NSMenu()

        llmEnableItem = NSMenuItem(title: "Enable",
                                   action: #selector(toggleLLM(_:)),
                                   keyEquivalent: "")
        llmEnableItem.target = self
        llmEnableItem.state  = Preferences.llmEnabled ? .on : .off
        llmMenu.addItem(llmEnableItem)

        llmMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        llmParent.submenu = llmMenu
        menu.addItem(llmParent)

        let statsItem = NSMenuItem(title: "Statistics & History…",
                                      action: #selector(openStats),
                                      keyEquivalent: "")
        statsItem.target = self
        menu.addItem(statsItem)

        menu.addItem(.separator())

        // ── Quit ─────────────────────────────────────────────────────────────
        let quit = NSMenuItem(title: "Quit VoiceInput",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw  = sender.representedObject as? String,
              let lang = Preferences.Language(rawValue: raw) else { return }
        Preferences.selectedLanguage = lang

        // Update checkmarks
        languageMenuItems.forEach { $0.state = .off }
        sender.state = .on
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        Preferences.llmEnabled.toggle()
        sender.state = Preferences.llmEnabled ? .on : .off
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func openStats() {
        if statsController == nil {
            statsController = StatisticsWindowController()
        }
        statsController?.loadData()
        statsController?.showWindow(nil)
        statsController?.window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
