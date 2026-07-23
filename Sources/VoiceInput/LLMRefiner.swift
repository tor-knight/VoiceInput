import Foundation

/// Calls an OpenAI-compatible chat completion API to conservatively fix
/// obvious speech-recognition errors (homophones, mis-recognised tech terms).
final class LLMRefiner {

    private static let systemPrompt = """
    You are a speech-recognition error corrector. Your job is to fix ONLY obvious \
    speech-to-text mistakes in the text the user provides.

    Rules (follow strictly):
    1. Fix only clear speech-recognition errors, for example:
       • Chinese homophones that are actually English technical terms
         (e.g. "配森" → "Python", "杰森" → "JSON", "基特" → "Git",
          "布尔" can stay as-is if contextually correct)
       • Obvious misheard words where the correct word is unambiguous
    2. Do NOT rephrase, rewrite, summarise, or polish anything.
    3. Do NOT add or remove words unless correcting a recognition error.
    4. Do NOT add punctuation or capitalisation that wasn't implied by context.
    5. If the text looks correct, return it EXACTLY as-is — byte for byte.
    6. Output ONLY the (possibly corrected) text. No explanations, no markdown.
    """

    // MARK: - Helper to build request

    private func buildRequest(forTest: Bool, text: String) -> URLRequest? {
        let provider = Preferences.llmProvider
        let baseURL = Preferences.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey  = Preferences.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model   = Preferences.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)

        let apiKeyRequired = (provider != .ollama && provider != .custom)
        if apiKeyRequired && apiKey.isEmpty {
            logDebug("LLMRefiner - missing API key for provider \(provider.rawValue)"); return nil
        }

        let timeout: TimeInterval = forTest ? 15 : 30

        if provider == .anthropic {
            // Anthropic Claude
            guard let url = URL(string: baseURL + (baseURL.hasSuffix("/") ? "messages" : "/messages")) else {
                return nil
            }
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            var body: [String: Any] = [
                "model": model,
                "max_tokens": forTest ? 10 : 1024,
                "messages": [
                    ["role": "user", "content": text]
                ],
                "temperature": 0.1
            ]
            if !forTest {
                body["system"] = Self.systemPrompt
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            return request
        } else {
            // OpenAI-compatible
            guard let url = URL(string: baseURL + (baseURL.hasSuffix("/") ? "chat/completions" : "/chat/completions")) else {
                return nil
            }
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            var body: [String: Any] = [
                "model": model,
                "max_tokens": forTest ? 10 : 1024,
                "temperature": 0.1
            ]
            if forTest {
                body["messages"] = [
                    ["role": "user", "content": text]
                ]
            } else {
                body["messages"] = [
                    ["role": "system", "content": Self.systemPrompt],
                    ["role": "user",   "content": text]
                ]
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            return request
        }
    }

    // MARK: - Refine

    func refine(text: String, completion: @escaping (String) -> Void) {
        guard !text.isEmpty else { completion(text); return }

        guard let request = buildRequest(forTest: false, text: text) else {
            completion(text)
            return
        }

                logDebug("LLMRefiner - Sending refine request to \(request.url?.absoluteString ?? "unknown"). Body size: \(request.httpBody?.count ?? 0) bytes.")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            logDebug("LLMRefiner - Received response. Status: \(httpStatus) | Error: \(error?.localizedDescription ?? "none") | Data bytes: \(data?.count ?? 0)")
            if let data = data, let str = String(data: data, encoding: .utf8) {
                logDebug("LLMRefiner - Response body:\n\(str)")
            }
            guard let data else {
                if let error { print("[VoiceInput] LLM network error: \(error.localizedDescription)") }
                completion(text)
                return
            }

            let provider = Preferences.llmProvider
            var refinedText: String? = nil

            if provider == .anthropic {
                // Parse Anthropic response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstBlock = content.first,
                   let textBlock = firstBlock["text"] as? String {
                    refinedText = textBlock
                }
            } else {
                // Parse OpenAI-compatible response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    refinedText = content
                }
            }

            if let refinedText = refinedText {
                completion(refinedText.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[VoiceInput] LLM parse error. Response was: \(responseString)")
                }
                completion(text)
            }
        }.resume()
    }

    // MARK: - Test connection

    func test(completion: @escaping (Bool, String) -> Void) {
        guard let request = buildRequest(forTest: true, text: "Reply with the word ok") else {
            completion(false, "Invalid URL or empty API Key")
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                completion(true, "Connection successful ✓")
            } else {
                let msg = error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                completion(false, "Failed: \(msg)")
            }
        }.resume()
    }
}
