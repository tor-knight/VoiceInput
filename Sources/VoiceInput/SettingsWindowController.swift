import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private var providerPopUp: NSPopUpButton!
    private var baseURLField: NSTextField!
    private var apiKeyField:  NSTextField!   // plain text so key can be selected & deleted fully
    private var modelField:   NSTextField!
    private var statusLabel:  NSTextField!
    private let refiner = LLMRefiner()

    // MARK: - Init

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 270),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        win.title = "VoiceInput — LLM Settings"
        win.center()
        self.init(window: win)
        win.delegate = self
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // Helper: right-aligned label
        func label(_ s: String) -> NSTextField {
            let f = NSTextField(labelWithString: s)
            f.alignment = .right
            return f
        }

        let providerLabel = label("Provider:")
        let urlLabel   = label("API Base URL:")
        let keyLabel   = label("API Key:")
        let modelLabel = label("Model:")

        providerPopUp = NSPopUpButton()
        providerPopUp.addItems(withTitles: Preferences.LLMProvider.allCases.map { $0.rawValue })
        providerPopUp.selectItem(withTitle: Preferences.llmProvider.rawValue)
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged)

        baseURLField = NSTextField(string: "")
        baseURLField.placeholderString = "https://api.openai.com/v1"
        baseURLField.stringValue = Preferences.llmBaseURL

        apiKeyField = NSTextField(string: "")
        apiKeyField.stringValue = Preferences.llmAPIKey
        // Use a cell that shows text (not masked) so user can visually select-all & delete
        apiKeyField.cell?.isScrollable = true

        modelField = NSTextField(string: "")
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = Preferences.llmModel

        // Initialize state
        updateApiKeyPlaceholder(for: Preferences.llmProvider)

        // Grid layout
        let grid = NSGridView(views: [
            [providerLabel, providerPopUp],
            [urlLabel,   baseURLField],
            [keyLabel,   apiKeyField],
            [modelLabel, modelField],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 330
        grid.rowSpacing    = 12
        grid.columnSpacing = 8
        cv.addSubview(grid)

        // Buttons row
        let testBtn = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle   = .rounded
        saveBtn.keyEquivalent = "\r"

        let btnStack = NSStackView(views: [NSView(), testBtn, saveBtn])
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        btnStack.orientation = .horizontal
        btnStack.spacing     = 8
        cv.addSubview(btnStack)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font      = .systemFont(ofSize: 12)
        cv.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: cv.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),

            btnStack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            btnStack.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -20),

            statusLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            statusLabel.centerYAnchor.constraint(equalTo: btnStack.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: btnStack.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - Actions

    @objc private func providerChanged() {
        guard let title = providerPopUp.selectedItem?.title,
              let provider = Preferences.LLMProvider(rawValue: title) else { return }

        baseURLField.stringValue = provider.defaultURL
        modelField.stringValue = provider.defaultModel
        updateApiKeyPlaceholder(for: provider)
    }

    @objc private func testConnection() {
        flushToPreferences()
        setStatus("Testing...", color: .secondaryLabelColor)

        refiner.test { [weak self] ok, msg in
            DispatchQueue.main.async {
                self?.setStatus(msg, color: ok ? .systemGreen : .systemRed)
            }
        }
    }

    @objc private func save() {
        flushToPreferences()
        setStatus("Saved.", color: .systemGreen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.close()
        }
    }

    // MARK: - Helpers

    private func updateApiKeyPlaceholder(for provider: Preferences.LLMProvider) {
        switch provider {
        case .ollama:
            apiKeyField.placeholderString = "Not required"
        case .gemini:
            apiKeyField.placeholderString = "AIzaSy..."
        default:
            apiKeyField.placeholderString = "sk-..."
        }
    }

    private func flushToPreferences() {
        if let title = providerPopUp.selectedItem?.title,
           let provider = Preferences.LLMProvider(rawValue: title) {
            Preferences.llmProvider = provider
        }
        Preferences.llmBaseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Preferences.llmAPIKey  = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Preferences.llmModel   = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setStatus(_ msg: String, color: NSColor) {
        statusLabel.stringValue = msg
        statusLabel.textColor   = color
    }

    // NSWindowDelegate: reset status when re-opened
    func windowWillClose(_ notification: Notification) {}
}
