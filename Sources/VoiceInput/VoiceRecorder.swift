import AVFoundation
import Speech
import Foundation
import Accelerate

/// Manages audio capture and streaming speech recognition.
/// Provides real-time RMS levels and incremental transcription.
final class VoiceRecorder {
    /// Called on background thread; dispatch to main before touching UI.
    var onTranscription: ((String) -> Void)?
    var onRMSUpdate:     ((Float) -> Void)?

    private var audioEngine:        AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?
    private var speechRecognizer:   SFSpeechRecognizer?

    private var currentText   = ""
    private var stopCallback: ((String) -> Void)?
    private var isStopping    = false
    private var fallbackTimer: DispatchWorkItem?

    // MARK: - Start

    func startRecording(locale: Locale) {
        stopPrevious()
        currentText = ""
        isStopping  = false

        let recognizer = SFSpeechRecognizer(locale: locale)
        recognizer?.defaultTaskHint = .dictation
        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults   = true
        request.requiresOnDeviceRecognition  = false
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.computeRMS(buffer: buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            print("[VoiceInput] AVAudioEngine start failed: \(error)")
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.currentText = text
                self.onTranscription?(text)

                if result.isFinal {
                    self.deliverFinalText(text)
                }
            }

            if let error {
                // AVAudioSession errors 203/216 are normal session interruptions; others warrant logging.
                let nsError = error as NSError
                if nsError.code != 203 && nsError.code != 216 {
                    print("[VoiceInput] Recognition error: \(error.localizedDescription)")
                }
                self.deliverFinalText(self.currentText)
            }
        }
    }

    // MARK: - Stop

    func stopRecording(completion: @escaping (String) -> Void) {
        guard !isStopping else { return }
        isStopping   = true
        stopCallback = completion

        // Stop audio capture
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        // Signal end-of-audio so recognition can finalise
        recognitionRequest?.endAudio()

        // Fallback: if recognition doesn't finalise within 3 s, deliver what we have
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isStopping else { return }
            self.deliverFinalText(self.currentText)
        }
        fallbackTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    // MARK: - Private helpers

    private func deliverFinalText(_ text: String) {
        guard isStopping else { return }
        fallbackTimer?.cancel()
        fallbackTimer = nil

        let cb = stopCallback
        stopCallback = nil
        isStopping   = false

        cb?(text)
    }

    private func stopPrevious() {
        fallbackTimer?.cancel()
        fallbackTimer  = nil
        stopCallback   = nil
        isStopping     = false

        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine    = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        speechRecognizer   = nil
        currentText = ""
    }

    // MARK: - RMS

    private func computeRMS(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var sum: Float = 0
        vDSP_measqv(data, 1, &sum, vDSP_Length(frameCount))
        let rms = sqrt(sum)

        onRMSUpdate?(rms)
    }
}
