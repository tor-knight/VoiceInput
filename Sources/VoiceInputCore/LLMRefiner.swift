import Foundation

public final class LLMRefiner {
    public static let systemPrompt = """
    You are a speech-recognition error corrector and formatter. Your job is to fix \
    speech-to-text mistakes AND add proper punctuation to the text the user provides.

    Rules (follow strictly):
    1. Fix speech-recognition errors, for example:
       • Chinese homophones that are actually English technical terms
         (e.g. "配森" → "Python", "杰森" → "JSON", "基特" → "Git")
       • Obvious misheard words.
    2. Add appropriate punctuation (commas, periods, question marks) to make the text \
       grammatically correct and easy to read.
    3. Do NOT rephrase, rewrite, summarise, or change the original meaning of the text.
    4. Output ONLY the corrected and punctuated text. No explanations, no markdown.
    """

    public init() {}

    // MARK: - Helper to build request

    private func buildRequest(systemPrompt: String?, userPrompt: String, maxTokens: Int) -> URLRequest? {
        let provider = Preferences.llmProvider
        let baseURL = Preferences.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey  = Preferences.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model   = Preferences.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)

        let apiKeyRequired = (provider != .ollama && provider != .custom)
        if apiKeyRequired && apiKey.isEmpty {
            logDebug("LLMRefiner - missing API key for provider \(provider.rawValue)")
            return nil
        }

        let timeout: TimeInterval = 30

        if provider == .anthropic {
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
                "max_tokens": maxTokens,
                "messages": [
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": 0.1
            ]
            if let system = systemPrompt {
                body["system"] = system
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            return request
        } else {
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
                "max_tokens": maxTokens,
                "temperature": 0.1
            ]
            var messages: [[String: String]] = []
            if let system = systemPrompt {
                messages.append(["role": "system", "content": system])
            }
            messages.append(["role": "user", "content": userPrompt])
            body["messages"] = messages

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            return request
        }
    }

    // MARK: - Refine

    public func refine(text: String, completion: @escaping (String) -> Void) {
        guard !text.isEmpty else {
            completion(text)
            return
        }

        generate(systemPrompt: Self.systemPrompt, userPrompt: text, maxTokens: 1024) { result in
            completion(result ?? text)
        }
    }

    // MARK: - Generic Generate

    public func generate(systemPrompt: String?, userPrompt: String, maxTokens: Int, completion: @escaping (String?) -> Void) {
        guard let request = buildRequest(systemPrompt: systemPrompt, userPrompt: userPrompt, maxTokens: maxTokens) else {
            completion(nil)
            return
        }

        logDebug("LLMRefiner - Sending LLM request to \(request.url?.absoluteString ?? "unknown").")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            logDebug("LLMRefiner - Received response. Status: \(httpStatus) | Error: \(error?.localizedDescription ?? "none") | Data bytes: \(data?.count ?? 0)")

            guard let data else {
                if let error {
                    print("[VoiceInput] LLM network error: \(error.localizedDescription)")
                }
                completion(nil)
                return
            }

            let provider = Preferences.llmProvider
            var resultText: String? = nil

            if provider == .anthropic {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstBlock = content.first,
                   let textBlock = firstBlock["text"] as? String {
                    resultText = textBlock
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    resultText = content
                }
            }

            if let resultText = resultText {
                completion(resultText.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Test connection

    public func test(completion: @escaping (Bool, String) -> Void) {
        guard let request = buildRequest(systemPrompt: nil, userPrompt: "Reply with the word ok", maxTokens: 10) else {
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
