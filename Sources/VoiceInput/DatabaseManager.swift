import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    
    private init() {
        openDatabase()
        createTable()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectoryURL = appSupportURL.appendingPathComponent("VoiceInput", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try? fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true)
        }
        
        let dbURL = appDirectoryURL.appendingPathComponent("speech_logs.sqlite")
        
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("[DatabaseManager] Error opening database at \(dbURL.path)")
            db = nil
        } else {
            print("[DatabaseManager] Successfully opened database at \(dbURL.path)")
        }
    }
    
    private func createTable() {
        guard let db = db else { return }
        
        let createTableString = """
        CREATE TABLE IF NOT EXISTS speech_logs (
            id TEXT PRIMARY KEY,
            created_at REAL,
            duration_ms REAL,
            char_count INTEGER,
            estimated_tokens INTEGER,
            original_text TEXT,
            refined_text TEXT,
            model_used TEXT,
            is_synced INTEGER DEFAULT 0
        );
        """
        
        var createTableStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("[DatabaseManager] speech_logs table created or already exists.")
            } else {
                print("[DatabaseManager] speech_logs table could not be created.")
            }
        } else {
            print("[DatabaseManager] CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func insertLog(id: String, createdAt: Date, durationMs: Double, charCount: Int, estimatedTokens: Int, originalText: String, refinedText: String, modelUsed: String) {
        guard let db = db else { return }
        
        let insertStatementString = "INSERT INTO speech_logs (id, created_at, duration_ms, char_count, estimated_tokens, original_text, refined_text, model_used, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
        
        var insertStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 2, createdAt.timeIntervalSince1970)
            sqlite3_bind_double(insertStatement, 3, durationMs)
            sqlite3_bind_int(insertStatement, 4, Int32(charCount))
            sqlite3_bind_int(insertStatement, 5, Int32(estimatedTokens))
            sqlite3_bind_text(insertStatement, 6, (originalText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 7, (refinedText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 8, (modelUsed as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 9, 0)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("[DatabaseManager] Successfully inserted row.")
            } else {
                print("[DatabaseManager] Could not insert row.")
            }
        } else {
            print("[DatabaseManager] INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
    }
}

struct SpeechLog {
    let id: String
    let createdAt: Date
    let durationMs: Double
    let charCount: Int
    let estimatedTokens: Int
    let originalText: String
    let refinedText: String
    let modelUsed: String
    let isSynced: Bool
}

struct SpeechStatistics {
    let todayWords: Int
    let todayDurationMs: Double
    let todayTokens: Int
    let totalWords: Int
    let totalDurationMs: Double
    let totalTokens: Int
}

extension DatabaseManager {
    
    func getUnsyncedLogs() -> [SpeechLog] {
        guard let db = db else { return [] }
        
        let queryStatementString = "SELECT id, created_at, duration_ms, char_count, estimated_tokens, original_text, refined_text, model_used, is_synced FROM speech_logs WHERE is_synced = 0;"
        var queryStatement: OpaquePointer? = nil
        var logs: [SpeechLog] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(queryStatement, 0))
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(queryStatement, 1))
                let durationMs = sqlite3_column_double(queryStatement, 2)
                let charCount = Int(sqlite3_column_int(queryStatement, 3))
                let estimatedTokens = Int(sqlite3_column_int(queryStatement, 4))
                let originalText = String(cString: sqlite3_column_text(queryStatement, 5))
                let refinedText = String(cString: sqlite3_column_text(queryStatement, 6))
                let modelUsed = String(cString: sqlite3_column_text(queryStatement, 7))
                let isSynced = sqlite3_column_int(queryStatement, 8) != 0
                
                let log = SpeechLog(id: id, createdAt: createdAt, durationMs: durationMs, charCount: charCount, estimatedTokens: estimatedTokens, originalText: originalText, refinedText: refinedText, modelUsed: modelUsed, isSynced: isSynced)
                logs.append(log)
            }
        } else {
            print("[DatabaseManager] SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        
        return logs
    }
    
    func markAsSynced(ids: [String]) {
        guard let db = db, !ids.isEmpty else { return }
        
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let updateStatementString = "UPDATE speech_logs SET is_synced = 1 WHERE id IN (\(placeholders));"
        
        var updateStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
            for (index, id) in ids.enumerated() {
                sqlite3_bind_text(updateStatement, Int32(index + 1), (id as NSString).utf8String, -1, nil)
            }
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("[DatabaseManager] Successfully updated synced status.")
            } else {
                print("[DatabaseManager] Could not update synced status.")
            }
        } else {
            print("[DatabaseManager] UPDATE statement could not be prepared.")
        }
        sqlite3_finalize(updateStatement)
    }
    
    func getAllLogs(limit: Int = 100, offset: Int = 0) -> [SpeechLog] {
        guard let db = db else { return [] }
        
        let queryStatementString = "SELECT id, created_at, duration_ms, char_count, estimated_tokens, original_text, refined_text, model_used, is_synced FROM speech_logs ORDER BY created_at DESC LIMIT ? OFFSET ?;"
        var queryStatement: OpaquePointer? = nil
        var logs: [SpeechLog] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(queryStatement, 1, Int32(limit))
            sqlite3_bind_int(queryStatement, 2, Int32(offset))
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(queryStatement, 0))
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(queryStatement, 1))
                let durationMs = sqlite3_column_double(queryStatement, 2)
                let charCount = Int(sqlite3_column_int(queryStatement, 3))
                let estimatedTokens = Int(sqlite3_column_int(queryStatement, 4))
                let originalText = String(cString: sqlite3_column_text(queryStatement, 5))
                let refinedText = String(cString: sqlite3_column_text(queryStatement, 6))
                let modelUsed = String(cString: sqlite3_column_text(queryStatement, 7))
                let isSynced = sqlite3_column_int(queryStatement, 8) != 0
                
                let log = SpeechLog(id: id, createdAt: createdAt, durationMs: durationMs, charCount: charCount, estimatedTokens: estimatedTokens, originalText: originalText, refinedText: refinedText, modelUsed: modelUsed, isSynced: isSynced)
                logs.append(log)
            }
        }
        sqlite3_finalize(queryStatement)
        
        return logs
    }
    
    func getStatistics() -> SpeechStatistics {
        guard let db = db else {
            return SpeechStatistics(todayWords: 0, todayDurationMs: 0, todayTokens: 0, totalWords: 0, totalDurationMs: 0, totalTokens: 0)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTodayTimestamp = startOfToday.timeIntervalSince1970

        var todayWords = 0
        var todayDuration = 0.0
        var todayTokens = 0

        var totalWords = 0
        var totalDuration = 0.0
        var totalTokens = 0

        let queryToday = "SELECT SUM(char_count), SUM(duration_ms), SUM(estimated_tokens) FROM speech_logs WHERE created_at >= ?;"
        var stmtToday: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, queryToday, -1, &stmtToday, nil) == SQLITE_OK {
            sqlite3_bind_double(stmtToday, 1, startOfTodayTimestamp)
            if sqlite3_step(stmtToday) == SQLITE_ROW {
                todayWords = Int(sqlite3_column_int(stmtToday, 0))
                todayDuration = sqlite3_column_double(stmtToday, 1)
                todayTokens = Int(sqlite3_column_int(stmtToday, 2))
            }
        }
        sqlite3_finalize(stmtToday)

        let queryTotal = "SELECT SUM(char_count), SUM(duration_ms), SUM(estimated_tokens) FROM speech_logs;"
        var stmtTotal: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, queryTotal, -1, &stmtTotal, nil) == SQLITE_OK {
            if sqlite3_step(stmtTotal) == SQLITE_ROW {
                totalWords = Int(sqlite3_column_int(stmtTotal, 0))
                totalDuration = sqlite3_column_double(stmtTotal, 1)
                totalTokens = Int(sqlite3_column_int(stmtTotal, 2))
            }
        }
        sqlite3_finalize(stmtTotal)

        return SpeechStatistics(todayWords: todayWords, todayDurationMs: todayDuration, todayTokens: todayTokens, totalWords: totalWords, totalDurationMs: totalDuration, totalTokens: totalTokens)
    }

    #if DEBUG
    func deleteAllLogsForTesting() {
        guard let db = db else { return }
        let deleteStatementString = "DELETE FROM speech_logs;"
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
    }
    #endif
}
