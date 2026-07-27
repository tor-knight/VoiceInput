import Foundation

public struct SpeechLog {
    public let id: String
    public let createdAt: Date
    public let durationMs: Double
    public let charCount: Int
    public let estimatedTokens: Int
    public let originalText: String
    public let refinedText: String
    public let modelUsed: String
    public let isSynced: Bool

    public init(
        id: String,
        createdAt: Date,
        durationMs: Double,
        charCount: Int,
        estimatedTokens: Int,
        originalText: String,
        refinedText: String,
        modelUsed: String,
        isSynced: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.charCount = charCount
        self.estimatedTokens = estimatedTokens
        self.originalText = originalText
        self.refinedText = refinedText
        self.modelUsed = modelUsed
        self.isSynced = isSynced
    }
}

public struct SpeechStatistics {
    public let todayWords: Int
    public let todayDurationMs: Double
    public let todayTokens: Int
    public let totalWords: Int
    public let totalDurationMs: Double
    public let totalTokens: Int

    public init(
        todayWords: Int,
        todayDurationMs: Double,
        todayTokens: Int,
        totalWords: Int,
        totalDurationMs: Double,
        totalTokens: Int
    ) {
        self.todayWords = todayWords
        self.todayDurationMs = todayDurationMs
        self.todayTokens = todayTokens
        self.totalWords = totalWords
        self.totalDurationMs = totalDurationMs
        self.totalTokens = totalTokens
    }
}
