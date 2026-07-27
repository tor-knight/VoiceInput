import Foundation

public func logDebug(_ msg: String) {
    #if os(iOS)
    let fileManager = FileManager.default
    let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let path = cacheURL.appendingPathComponent("VoiceInput.log").path
    #else
    let path = "/tmp/VoiceInput.log"
    #endif

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    let dateStr = formatter.string(from: Date())
    let text = "[\(dateStr)] \(msg)\n"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(text.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
