import XCTest
@testable import VoiceInput

final class DatabaseManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DatabaseManager.shared.deleteAllLogsForTesting()
    }
    
    override func tearDown() {
        DatabaseManager.shared.deleteAllLogsForTesting()
        super.tearDown()
    }
    
    func testInsertAndFetchUnsyncedLogs() {
        let db = DatabaseManager.shared
        
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString
        
        db.insertLog(
            id: id1,
            createdAt: Date(),
            durationMs: 1500,
            charCount: 10,
            estimatedTokens: 15,
            originalText: "Hello",
            refinedText: "Hello.",
            modelUsed: "gpt-4o-mini"
        )
        
        db.insertLog(
            id: id2,
            createdAt: Date(),
            durationMs: 2000,
            charCount: 20,
            estimatedTokens: 30,
            originalText: "World",
            refinedText: "World!",
            modelUsed: "gpt-4o-mini"
        )
        
        let unsynced = db.getUnsyncedLogs()
        XCTAssertEqual(unsynced.count, 2)
        XCTAssertTrue(unsynced.contains(where: { $0.id == id1 }))
        XCTAssertTrue(unsynced.contains(where: { $0.id == id2 }))
    }
    
    func testMarkAsSynced() {
        let db = DatabaseManager.shared
        let id1 = UUID().uuidString
        
        db.insertLog(
            id: id1,
            createdAt: Date(),
            durationMs: 1500,
            charCount: 10,
            estimatedTokens: 15,
            originalText: "Test",
            refinedText: "Test.",
            modelUsed: "gpt-4o-mini"
        )
        
        XCTAssertEqual(db.getUnsyncedLogs().count, 1)
        
        db.markAsSynced(ids: [id1])
        
        XCTAssertEqual(db.getUnsyncedLogs().count, 0)
    }
    
    func testGetStatistics() {
        let db = DatabaseManager.shared
        
        db.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 1000, // 1 sec
            charCount: 10,
            estimatedTokens: 15,
            originalText: "One",
            refinedText: "One",
            modelUsed: "None"
        )
        
        db.insertLog(
            id: UUID().uuidString,
            createdAt: Date(),
            durationMs: 2000, // 2 sec
            charCount: 20,
            estimatedTokens: 30,
            originalText: "Two",
            refinedText: "Two",
            modelUsed: "None"
        )
        
        let stats = db.getStatistics()
        
        XCTAssertEqual(stats.todayWords, 30)
        XCTAssertEqual(stats.todayDurationMs, 3000)
        XCTAssertEqual(stats.todayTokens, 45)
        
        XCTAssertEqual(stats.totalWords, 30)
        XCTAssertEqual(stats.totalDurationMs, 3000)
        XCTAssertEqual(stats.totalTokens, 45)
    }
}
