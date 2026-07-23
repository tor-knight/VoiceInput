import Foundation

final class SyncService {
    static let shared = SyncService()
    
    private let queue = DispatchQueue(label: "com.voiceinput.syncservice", qos: .background)
    private var isSyncing = false
    
    private init() {}
    
    func syncIfNeeded() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isSyncing else { return }
            
            guard Preferences.syncEnabled else { return }
            
            let vpsURLString = Preferences.syncVPSURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !vpsURLString.isEmpty, let url = URL(string: vpsURLString) else { return }
            
            let logs = DatabaseManager.shared.getUnsyncedLogs()
            guard !logs.isEmpty else { return }
            
            self.isSyncing = true
            
            let payload = logs.map { log -> [String: Any] in
                return [
                    "id": log.id,
                    "created_at": log.createdAt.timeIntervalSince1970,
                    "duration_ms": log.durationMs,
                    "char_count": log.charCount,
                    "estimated_tokens": log.estimatedTokens,
                    "original_text": log.originalText,
                    "refined_text": log.refinedText,
                    "model_used": log.modelUsed
                ]
            }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                self.isSyncing = false
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let apiKey = Preferences.syncAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                defer { self.isSyncing = false }
                
                if let error = error {
                    print("[SyncService] Sync failed with error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    let ids = logs.map { $0.id }
                    DatabaseManager.shared.markAsSynced(ids: ids)
                    print("[SyncService] Successfully synced \(ids.count) logs.")
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("[SyncService] Sync failed with status code: \(statusCode)")
                }
            }
            
            task.resume()
        }
    }
}
