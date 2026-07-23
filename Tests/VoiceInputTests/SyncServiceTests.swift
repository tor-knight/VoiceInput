import XCTest
@testable import VoiceInput

final class SyncServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DatabaseManager.shared.deleteAllLogsForTesting()
        
        // Reset preferences
        Preferences.syncEnabled = false
        Preferences.syncVPSURL = ""
        Preferences.syncAPIKey = ""
    }
    
    override func tearDown() {
        DatabaseManager.shared.deleteAllLogsForTesting()
        super.tearDown()
    }
    
    // In this basic test suite without external mocking libraries (like OHHTTPStubs)
    // we can mainly test that the payload serialization and preconditions work.
    // Full network interception might require URLProtocol subclassing.
    
    func testSyncBailsOutIfDisabled() {
        Preferences.syncEnabled = false
        
        let expectation = XCTestExpectation(description: "Wait for background queue")
        
        // Insert a log
        DatabaseManager.shared.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 10,
            estimatedTokens: 15,
            originalText: "Hello",
            refinedText: "Hello",
            modelUsed: "None"
        )
        
        XCTAssertEqual(DatabaseManager.shared.getUnsyncedLogs().count, 1)
        
        SyncService.shared.syncIfNeeded()
        
        // Give the background queue a moment to process
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should still be unsynced because sync was disabled
        XCTAssertEqual(DatabaseManager.shared.getUnsyncedLogs().count, 1)
    }
    
    func testSyncBailsOutIfNoURL() {
        Preferences.syncEnabled = true
        Preferences.syncVPSURL = ""
        
        let expectation = XCTestExpectation(description: "Wait for background queue")
        
        DatabaseManager.shared.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000,
            charCount: 10,
            estimatedTokens: 15,
            originalText: "Hello",
            refinedText: "Hello",
            modelUsed: "None"
        )
        
        SyncService.shared.syncIfNeeded()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should still be unsynced because URL was empty
        XCTAssertEqual(DatabaseManager.shared.getUnsyncedLogs().count, 1)
    }
}
