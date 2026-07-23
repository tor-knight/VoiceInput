import Foundation

func logDebug(_ msg: String) {
    let path = "/tmp/VoiceInput.log"
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