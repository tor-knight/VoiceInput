import AppKit

final class StatisticsWindowController: NSWindowController, NSWindowDelegate {
    
    private var segmentedControl: NSSegmentedControl!
    private var containerView: NSView!
    
    // Child Views
    private var overviewView: NSView!
    private var historyView: NSView!
    private var syncSettingsView: NSView!
    
    // Overview Labels
    private var todayWordsLabel: NSTextField!
    private var todayTimeLabel: NSTextField!
    private var todayTokensLabel: NSTextField!

    private var totalWordsLabel: NSTextField!
    private var totalTimeLabel: NSTextField!
    private var totalTokensLabel: NSTextField!

    private var summaryTextView: NSTextView!
    private var summaryButton: NSButton!
    private var summaryProgressIndicator: NSProgressIndicator!
    
    // History
    private var tableView: NSTableView!
    private var logs: [SpeechLog] = []
    private var isFetchingMoreLogs = false
    private let logsBatchSize = 100
    
    // Sync Settings
    private var enableSyncCheckbox: NSButton!
    private var vpsUrlField: NSTextField!
    private var apiKeyField: NSTextField!
    private var syncStatusLabel: NSTextField!
    
    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Statistics & History"
        win.minSize = NSSize(width: 500, height: 400)
        win.center()
        self.init(window: win)
        win.delegate = self
        buildUI()
        loadData()
    }
    
    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        
        segmentedControl = NSSegmentedControl(labels: ["Overview", "History", "Sync Settings"], trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentedControl)
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            segmentedControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        buildOverviewView()
        buildHistoryView()
        buildSyncSettingsView()
        
        switchToView(overviewView)
    }
    
    // MARK: - Overview
    
    private func buildOverviewView() {
        overviewView = NSView()
        overviewView.translatesAutoresizingMaskIntoConstraints = false
        
        let todayTitle = createLabel(text: "Today", isBold: true, fontSize: 18)
        todayWordsLabel = createLabel(text: "Words: 0")
        todayTimeLabel = createLabel(text: "Duration: 0s")
        todayTokensLabel = createLabel(text: "Tokens: 0")
        
        let totalTitle = createLabel(text: "All Time", isBold: true, fontSize: 18)
        totalWordsLabel = createLabel(text: "Words: 0")
        totalTimeLabel = createLabel(text: "Duration: 0s")
        totalTokensLabel = createLabel(text: "Tokens: 0")

        summaryButton = NSButton(title: "Generate Today's Summary (Local)", target: self, action: #selector(generateSummaryClicked))

        summaryProgressIndicator = NSProgressIndicator()
        summaryProgressIndicator.style = .spinning
        summaryProgressIndicator.isDisplayedWhenStopped = false
        summaryProgressIndicator.translatesAutoresizingMaskIntoConstraints = false

        let summaryHeaderStack = NSStackView(views: [summaryButton, summaryProgressIndicator])
        summaryHeaderStack.orientation = .horizontal
        summaryHeaderStack.spacing = 8
        summaryHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        summaryTextView = NSTextView()
        summaryTextView.isEditable = false
        summaryTextView.font = .systemFont(ofSize: 13)
        summaryTextView.backgroundColor = .windowBackgroundColor

        let scrollTextView = NSScrollView()
        scrollTextView.documentView = summaryTextView
        scrollTextView.hasVerticalScroller = true
        scrollTextView.translatesAutoresizingMaskIntoConstraints = false
        scrollTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        let stackView = NSStackView(views: [
            todayTitle, todayWordsLabel, todayTimeLabel, todayTokensLabel,
            createLabel(text: ""), // spacer
            totalTitle, totalWordsLabel, totalTimeLabel, totalTokensLabel,
            createLabel(text: ""), // spacer
            summaryHeaderStack,
            scrollTextView
        ])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        overviewView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: overviewView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: overviewView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: overviewView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: overviewView.bottomAnchor, constant: -20),

            scrollTextView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            scrollTextView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
        ])
    }
    
    // MARK: - History
    
    private func buildHistoryView() {
        historyView = NSView()
        historyView.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()

        // Setup table for automatic row heights based on content
        tableView.usesAutomaticRowHeights = true
        tableView.rowSizeStyle = .custom
        tableView.intercellSpacing = NSSize(width: 8, height: 16)

        tableView.usesAlternatingRowBackgroundColors = true
        
        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateCol"))
        dateCol.title = "Date"
        dateCol.width = 120
        
        let textCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TextCol"))
        textCol.title = "Refined Text"
        textCol.width = 300
        
        let statsCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("StatsCol"))
        statsCol.title = "Stats (Chars / Tokens)"
        statsCol.width = 120
        
        tableView.addTableColumn(dateCol)
        tableView.addTableColumn(textCol)
        tableView.addTableColumn(statsCol)
        
        scrollView.documentView = tableView
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        historyView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: historyView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: historyView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: historyView.bottomAnchor)
        ])
    }
    
    // MARK: - Sync Settings
    
    private func buildSyncSettingsView() {
        syncSettingsView = NSView()
        syncSettingsView.translatesAutoresizingMaskIntoConstraints = false
        
        enableSyncCheckbox = NSButton(checkboxWithTitle: "Enable VPS Sync", target: self, action: #selector(syncSettingsChanged))
        
        let urlLabel = createLabel(text: "VPS Endpoint URL:")
        vpsUrlField = NSTextField()
        vpsUrlField.placeholderString = "https://your-vps.com/api/sync"
        vpsUrlField.delegate = self
        
        let apiKeyLabel = createLabel(text: "Authorization Bearer Token:")
        apiKeyField = NSSecureTextField()
        apiKeyField.placeholderString = "Optional API Key"
        apiKeyField.delegate = self
        
        syncStatusLabel = createLabel(text: "Unsynced Records: 0")
        syncStatusLabel.textColor = .secondaryLabelColor
        
        let manualSyncBtn = NSButton(title: "Force Sync Now", target: self, action: #selector(forceSyncClicked))
        
        let grid = NSGridView(views: [
            [enableSyncCheckbox, NSView()],
            [urlLabel, vpsUrlField],
            [apiKeyLabel, apiKeyField],
            [manualSyncBtn, syncStatusLabel]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowAlignment = .lastBaseline
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 1).width = 250
        grid.rowSpacing = 16
        
        syncSettingsView.addSubview(grid)
        
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: syncSettingsView.topAnchor, constant: 40),
            grid.centerXAnchor.constraint(equalTo: syncSettingsView.centerXAnchor)
        ])
        
        // Load prefs
        enableSyncCheckbox.state = Preferences.syncEnabled ? .on : .off
        vpsUrlField.stringValue = Preferences.syncVPSURL
        apiKeyField.stringValue = Preferences.syncAPIKey
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions & State
    
    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: switchToView(overviewView)
        case 1: switchToView(historyView)
        case 2: switchToView(syncSettingsView)
        default: break
        }
    }
    
    private func switchToView(_ view: NSView) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: containerView.topAnchor),
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        if view == historyView || view == overviewView {
            loadData()
        }
        if view == syncSettingsView {
            updateUnsyncedCount()
        }
    }
    
    func loadData() {
        let stats = DatabaseManager.shared.getStatistics()

        todayWordsLabel.stringValue = "Characters: \(stats.todayWords)"
        todayTimeLabel.stringValue = String(format: "Duration: %.1f seconds", stats.todayDurationMs / 1000.0)
        todayTokensLabel.stringValue = "Tokens Used: \(stats.todayTokens)"

        totalWordsLabel.stringValue = "Characters: \(stats.totalWords)"
        totalTimeLabel.stringValue = String(format: "Duration: %.1f minutes", (stats.totalDurationMs / 1000.0) / 60.0)
        totalTokensLabel.stringValue = "Tokens Used: \(stats.totalTokens)"

        logs = DatabaseManager.shared.getAllLogs(limit: logsBatchSize, offset: 0)
        tableView?.reloadData()
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        guard let contentView = notification.object as? NSClipView else { return }
        let documentVisibleRect = contentView.documentVisibleRect
        let documentBounds = contentView.documentView?.bounds ?? .zero

        // If we are within 200 points of the bottom, fetch more
        if documentVisibleRect.maxY >= documentBounds.height - 200 {
            fetchMoreLogsIfNeeded()
        }
    }

    private func fetchMoreLogsIfNeeded() {
        guard !isFetchingMoreLogs else { return }

        let currentCount = logs.count

        // Prevent fetching if we haven't loaded any data yet or if it's not a multiple of batch size
        // (meaning we've reached the end)
        if currentCount == 0 || currentCount % logsBatchSize != 0 {
            return
        }

        isFetchingMoreLogs = true

        // Fetch next batch
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let moreLogs = DatabaseManager.shared.getAllLogs(limit: self.logsBatchSize, offset: currentCount)

            DispatchQueue.main.async {
                guard !moreLogs.isEmpty else {
                    self.isFetchingMoreLogs = false
                    return
                }
                self.logs.append(contentsOf: moreLogs)
                self.tableView?.reloadData()
                self.isFetchingMoreLogs = false
            }
        }
    }
    
    private func updateUnsyncedCount() {
        let count = DatabaseManager.shared.getUnsyncedLogs().count
        syncStatusLabel.stringValue = "Unsynced Records: \(count)"
    }
    
    @objc private func syncSettingsChanged() {
        Preferences.syncEnabled = (enableSyncCheckbox.state == .on)
    }
    
    @objc private func generateSummaryClicked() {
        let todayLogs = DatabaseManager.shared.getLogsForToday()
        guard !todayLogs.isEmpty else {
            summaryTextView.string = "No voice inputs recorded today."
            return
        }

        // Check if LLM is configured
        let requiresKey = (Preferences.llmProvider != .ollama && Preferences.llmProvider != .custom)
        if requiresKey && Preferences.llmAPIKey.isEmpty {
            summaryTextView.string = "Please configure your LLM API Key in Settings first."
            return
        }

        summaryButton.isEnabled = false
        summaryProgressIndicator.startAnimation(nil)
        summaryTextView.string = "Generating summary..."

        let combinedText = todayLogs.map { $0.refinedText }.joined(separator: "\n")
        let prompt = """
        \(Preferences.summaryPrompt)

        \(combinedText)
        """

        let provider = Preferences.llmProvider
        let baseURL = Preferences.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = Preferences.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = Preferences.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)

        var request: URLRequest?

        if provider == .anthropic {
            guard let url = URL(string: baseURL + (baseURL.hasSuffix("/") ? "messages" : "/messages")) else { return }
            request = URLRequest(url: url)
            request?.httpMethod = "POST"
            request?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request?.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request?.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let body: [String: Any] = [
                "model": model,
                "max_tokens": 1024,
                "messages": [ ["role": "user", "content": prompt] ]
            ]
            request?.httpBody = try? JSONSerialization.data(withJSONObject: body)
        } else {
            guard let url = URL(string: baseURL + (baseURL.hasSuffix("/") ? "chat/completions" : "/chat/completions")) else { return }
            request = URLRequest(url: url)
            request?.httpMethod = "POST"
            request?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request?.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            let body: [String: Any] = [
                "model": model,
                "max_tokens": 1024,
                "messages": [ ["role": "user", "content": prompt] ]
            ]
            request?.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        guard let finalRequest = request else {
            DispatchQueue.main.async {
                self.summaryProgressIndicator.stopAnimation(nil)
                self.summaryButton.isEnabled = true
                self.summaryTextView.string = "Failed to create API request."
            }
            return
        }

        URLSession.shared.dataTask(with: finalRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.summaryProgressIndicator.stopAnimation(nil)
                self.summaryButton.isEnabled = true

                if let error = error {
                    self.summaryTextView.string = "Error: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    self.summaryTextView.string = "No data returned."
                    return
                }

                var summaryResult: String?

                if provider == .anthropic {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let content = json["content"] as? [[String: Any]],
                       let text = content.first?["text"] as? String {
                        summaryResult = text
                    }
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        summaryResult = content
                    }
                }

                if let result = summaryResult {
                    self.summaryTextView.string = result
                } else {
                    let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
                    self.summaryTextView.string = "Failed to parse response: \(raw)"
                }
            }
        }.resume()
    }
    @objc private func forceSyncClicked() {
        SyncService.shared.syncIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateUnsyncedCount()
        }
    }
    
    // MARK: - Helpers
    
    private func createLabel(text: String, isBold: Bool = false, fontSize: CGFloat = 13) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        if isBold {
            lbl.font = .boldSystemFont(ofSize: fontSize)
        } else {
            lbl.font = .systemFont(ofSize: fontSize)
        }
        return lbl
    }
}

extension StatisticsWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field == vpsUrlField {
            Preferences.syncVPSURL = field.stringValue
        } else if field == apiKeyField {
            Preferences.syncAPIKey = field.stringValue
        }
    }
}

extension StatisticsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let log = logs[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = NSUserInterfaceItemIdentifier(identifier)
            let tf = NSTextField(labelWithString: "")
            tf.isEditable = false
            tf.isSelectable = true
            tf.isBordered = false
            tf.drawsBackground = false
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.cell?.wraps = true

            // Allow vertical expansion
            tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            tf.setContentCompressionResistancePriority(.required, for: .vertical)

            newCell.addSubview(tf)
            newCell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                tf.topAnchor.constraint(equalTo: newCell.topAnchor, constant: 8),
                tf.bottomAnchor.constraint(equalTo: newCell.bottomAnchor, constant: -8)
            ])
            return newCell
        }()
        
        if identifier == "DateCol" {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .medium
            cell.textField?.stringValue = df.string(from: log.createdAt)
        } else if identifier == "TextCol" {
            cell.textField?.stringValue = log.refinedText
        } else if identifier == "StatsCol" {
            cell.textField?.stringValue = "\(log.charCount)c / \(log.estimatedTokens)t"
        }
        
        return cell
    }
}
