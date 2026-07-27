import Foundation
import VoiceInputCore

// MARK: - Assertion Helpers

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ ASSERTION FAILED: \(message) at \(file):\(line)")
        exit(1)
    }
}

func assertEquals<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ ASSERTION FAILED: expected \(expected), got \(actual) - \(message) at \(file):\(line)")
        exit(1)
    }
}

// MARK: - Mock URLProtocol for API Interception

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is not set.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Cases

class DatabaseManagerTests {
    func setUp() {
        DatabaseManager.shared.deleteAllLogsForTesting()
    }

    func tearDown() {
        DatabaseManager.shared.deleteAllLogsForTesting()
    }

    func runAllTests() {
        print("Running DatabaseManagerTests...")

        setUp()
        testInsertAndFetchUnsyncedLogs()
        tearDown()

        setUp()
        testMarkAsSynced()
        tearDown()

        setUp()
        testGetStatistics()
        tearDown()

        print("✅ DatabaseManagerTests passed.")
    }

    func testInsertAndFetchUnsyncedLogs() {
        let db = DatabaseManager.shared
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString

        db.insertLog(
            id: id1,
            createdAt: Date(),
            durationMs: 1500,
            charCount: 5,
            estimatedTokens: 7,
            originalText: "Hello",
            refinedText: "Hello.",
            modelUsed: "gpt-4o-mini"
        )

        db.insertLog(
            id: id2,
            createdAt: Date(),
            durationMs: 2000,
            charCount: 5,
            estimatedTokens: 7,
            originalText: "World",
            refinedText: "World!",
            modelUsed: "gpt-4o-mini"
        )

        let unsynced = db.getUnsyncedLogs()
        assertEquals(unsynced.count, 2, "Unsynced count should be 2")
        assert(unsynced.contains(where: { $0.id == id1 }), "Should contain first log")
        assert(unsynced.contains(where: { $0.id == id2 }), "Should contain second log")
    }

    func testMarkAsSynced() {
        let db = DatabaseManager.shared
        let id = UUID().uuidString

        db.insertLog(
            id: id,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 4,
            estimatedTokens: 6,
            originalText: "Test",
            refinedText: "Test.",
            modelUsed: "gpt-4o-mini"
        )

        assertEquals(db.getUnsyncedLogs().count, 1, "Unsynced count should be 1")
        db.markAsSynced(ids: [id])
        assertEquals(db.getUnsyncedLogs().count, 0, "Unsynced count should be 0 after sync")
    }

    func testGetStatistics() {
        let db = DatabaseManager.shared

        db.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 3,
            estimatedTokens: 4,
            originalText: "One",
            refinedText: "One",
            modelUsed: "None"
        )

        db.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 2000,
            charCount: 3,
            estimatedTokens: 4,
            originalText: "Two",
            refinedText: "Two",
            modelUsed: "None"
        )

        let stats = db.getStatistics()
        assertEquals(stats.todayWords, 6, "Today words should be 6")
        assertEquals(stats.todayDurationMs, 3000.0, "Today duration should be 3000ms")
        assertEquals(stats.todayTokens, 8, "Today tokens should be 8")
        assertEquals(stats.totalWords, 6, "Total words should be 6")
        assertEquals(stats.totalDurationMs, 3000.0, "Total duration should be 3000ms")
        assertEquals(stats.totalTokens, 8, "Total tokens should be 8")
    }
}

class SyncServiceTests {
    func setUp() {
        DatabaseManager.shared.deleteAllLogsForTesting()
        Preferences.syncEnabled = false
        Preferences.syncVPSURL = ""
        Preferences.syncAPIKey = ""
    }

    func tearDown() {
        DatabaseManager.shared.deleteAllLogsForTesting()
    }

    func runAllTests() {
        print("Running SyncServiceTests...")

        setUp()
        testSyncBailsOutIfDisabled()
        tearDown()

        setUp()
        testSyncBailsOutIfNoURL()
        tearDown()

        print("✅ SyncServiceTests passed.")
    }

    func testSyncBailsOutIfDisabled() {
        Preferences.syncEnabled = false
        DatabaseManager.shared.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 5,
            estimatedTokens: 7,
            originalText: "Hello",
            refinedText: "Hello",
            modelUsed: "None"
        )

        assertEquals(DatabaseManager.shared.getUnsyncedLogs().count, 1, "Unsynced count should be 1")
        SyncService.shared.syncIfNeeded()

        // Wait for background queue to run
        Thread.sleep(forTimeInterval: 0.2)
        assertEquals(DatabaseManager.shared.getUnsyncedLogs().count, 1, "Should still be unsynced")
    }

    func testSyncBailsOutIfNoURL() {
        Preferences.syncEnabled = true
        Preferences.syncVPSURL = ""
        DatabaseManager.shared.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 5,
            estimatedTokens: 7,
            originalText: "Hello",
            refinedText: "Hello",
            modelUsed: "None"
        )

        assertEquals(DatabaseManager.shared.getUnsyncedLogs().count, 1, "Unsynced count should be 1")
        SyncService.shared.syncIfNeeded()

        // Wait for background queue to run
        Thread.sleep(forTimeInterval: 0.2)
        assertEquals(DatabaseManager.shared.getUnsyncedLogs().count, 1, "Should still be unsynced")
    }
}

class PreferencesTests {
    func runAllTests() {
        print("Running PreferencesTests...")

        // Save original settings
        let origLanguage = Preferences.selectedLanguage
        let origLlmEnabled = Preferences.llmEnabled
        let origLlmProvider = Preferences.llmProvider
        let origLlmBaseURL = Preferences.llmBaseURL
        let origLlmAPIKey = Preferences.llmAPIKey
        let origLlmModel = Preferences.llmModel
        let origSyncEnabled = Preferences.syncEnabled
        let origSyncVPSURL = Preferences.syncVPSURL
        let origSyncAPIKey = Preferences.syncAPIKey
        let origSummaryPrompt = Preferences.summaryPrompt

        // Test language
        Preferences.selectedLanguage = .english
        assertEquals(Preferences.selectedLanguage, .english, "Language should be English")
        Preferences.selectedLanguage = .simplifiedChinese
        assertEquals(Preferences.selectedLanguage, .simplifiedChinese, "Language should be Chinese")

        // Test LLM enable
        Preferences.llmEnabled = true
        assertEquals(Preferences.llmEnabled, true, "LLM should be enabled")
        Preferences.llmEnabled = false
        assertEquals(Preferences.llmEnabled, false, "LLM should be disabled")

        // Test provider and defaultURL/defaultModel mappings
        Preferences.llmProvider = .openai
        assertEquals(Preferences.llmProvider, .openai, "Provider should be OpenAI")
        assertEquals(Preferences.llmProvider.defaultURL, "https://api.openai.com/v1", "Default OpenAI URL")
        assertEquals(Preferences.llmProvider.defaultModel, "gpt-4o-mini", "Default OpenAI model")

        Preferences.llmProvider = .anthropic
        assertEquals(Preferences.llmProvider, .anthropic, "Provider should be Anthropic")
        assertEquals(Preferences.llmProvider.defaultURL, "https://api.anthropic.com/v1", "Default Anthropic URL")
        assertEquals(Preferences.llmProvider.defaultModel, "claude-3-5-haiku-latest", "Default Anthropic model")

        // Test base URL, key, model
        Preferences.llmBaseURL = "http://test-url"
        assertEquals(Preferences.llmBaseURL, "http://test-url", "Base URL should be test-url")
        Preferences.llmAPIKey = "test-key"
        assertEquals(Preferences.llmAPIKey, "test-key", "API key should be test-key")
        Preferences.llmModel = "test-model"
        assertEquals(Preferences.llmModel, "test-model", "Model should be test-model")

        // Test sync
        Preferences.syncEnabled = true
        assertEquals(Preferences.syncEnabled, true, "Sync should be enabled")
        Preferences.syncVPSURL = "http://vps-url"
        assertEquals(Preferences.syncVPSURL, "http://vps-url", "VPS URL should be vps-url")
        Preferences.syncAPIKey = "vps-key"
        assertEquals(Preferences.syncAPIKey, "vps-key", "VPS key should be vps-key")

        // Test summary prompt
        Preferences.summaryPrompt = "custom-prompt"
        assertEquals(Preferences.summaryPrompt, "custom-prompt", "Summary prompt should be custom-prompt")

        // Restore original settings
        Preferences.selectedLanguage = origLanguage
        Preferences.llmEnabled = origLlmEnabled
        Preferences.llmProvider = origLlmProvider
        Preferences.llmBaseURL = origLlmBaseURL
        Preferences.llmAPIKey = origLlmAPIKey
        Preferences.llmModel = origLlmModel
        Preferences.syncEnabled = origSyncEnabled
        Preferences.syncVPSURL = origSyncVPSURL
        Preferences.syncAPIKey = origSyncAPIKey
        Preferences.summaryPrompt = origSummaryPrompt

        print("✅ PreferencesTests passed.")
    }
}

class LLMRefinerTests {
    let originalProvider = Preferences.llmProvider
    let originalBaseURL = Preferences.llmBaseURL
    let originalAPIKey = Preferences.llmAPIKey
    let originalModel = Preferences.llmModel

    func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
    }

    func tearDown() {
        Preferences.llmProvider = originalProvider
        Preferences.llmBaseURL = originalBaseURL
        Preferences.llmAPIKey = originalAPIKey
        Preferences.llmModel = originalModel
    }

    func runAllTests() {
        print("Running LLMRefinerTests...")
        setUp()
        testSystemPrompt()
        testProviderValidation()
        tearDown()
        print("✅ LLMRefinerTests passed.")
    }

    func testSystemPrompt() {
        assert(!LLMRefiner.systemPrompt.isEmpty, "System prompt should not be empty")
        assert(LLMRefiner.systemPrompt.contains("speech-recognition"), "System prompt should be descriptive")
    }

    func testProviderValidation() {
        let refiner = LLMRefiner()

        Preferences.llmProvider = .custom
        Preferences.llmBaseURL = "http://invalid-test-url"
        Preferences.llmAPIKey = ""
        Preferences.llmModel = "model"

        // Refinement with empty string returns immediately without network request
        let expectation = DispatchSemaphore(value: 0)
        refiner.refine(text: "") { result in
            assertEquals(result, "", "Empty text refinement should return empty string")
            expectation.signal()
        }
        _ = expectation.wait(timeout: .now() + 1.0)
    }
}

// MARK: - Main Execution

@main
struct TestRunner {
    static func main() {
        print("=== STARTING TEST SUITE ===")
        Preferences.useInMemoryKeychain = true
        DatabaseManagerTests().runAllTests()
        SyncServiceTests().runAllTests()
        PreferencesTests().runAllTests()
        LLMRefinerTests().runAllTests()
        FnKeyMonitorTests().runAllTests()
        print("=== ALL TESTS PASSED SUCCESSFULLY 🎉 ===")
    }
}
