import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    // MARK: - Language

    enum Language: String, CaseIterable {
        case english           = "en-US"
        case simplifiedChinese = "zh-CN"
        case traditionalChinese = "zh-TW"
        case japanese          = "ja-JP"
        case korean            = "ko-KR"

        var displayName: String {
            switch self {
            case .english:            return "English"
            case .simplifiedChinese:  return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .japanese:           return "日本語"
            case .korean:             return "한국어"
            }
        }
    }

    static var selectedLanguage: Language {
        get {
            let raw = defaults.string(forKey: "selectedLanguage") ?? Language.simplifiedChinese.rawValue
            return Language(rawValue: raw) ?? .simplifiedChinese
        }
        set { defaults.set(newValue.rawValue, forKey: "selectedLanguage") }
    }

    // MARK: - LLM

    enum LLMProvider: String, CaseIterable, Codable {
        case openai = "OpenAI"
        case gemini = "Google Gemini"
        case anthropic = "Anthropic Claude"
        case deepseek = "DeepSeek"
        case openrouter = "OpenRouter"
        case ollama = "Ollama (Local)"
        case custom = "Custom"

        var defaultURL: String {
            switch self {
            case .openai:      return "https://api.openai.com/v1"
            case .gemini:      return "https://generativelanguage.googleapis.com/v1beta/openai"
            case .anthropic:   return "https://api.anthropic.com/v1"
            case .deepseek:    return "https://api.deepseek.com/v1"
            case .openrouter:  return "https://openrouter.ai/api/v1"
            case .ollama:      return "http://localhost:11434/v1"
            case .custom:      return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .openai:      return "gpt-4o-mini"
            case .gemini:      return "gemini-2.5-flash"
            case .anthropic:   return "claude-3-5-haiku-latest"
            case .deepseek:    return "deepseek-chat"
            case .openrouter:  return "google/gemini-2.5-flash"
            case .ollama:      return "llama3"
            case .custom:      return ""
            }
        }
    }

    static var llmProvider: LLMProvider {
        get {
            let raw = defaults.string(forKey: "llmProvider") ?? LLMProvider.openai.rawValue
            return LLMProvider(rawValue: raw) ?? .openai
        }
        set { defaults.set(newValue.rawValue, forKey: "llmProvider") }
    }

    static var llmEnabled: Bool {
        get { defaults.bool(forKey: "llmEnabled") }
        set { defaults.set(newValue, forKey: "llmEnabled") }
    }

    static var llmBaseURL: String {
        get { defaults.string(forKey: "llmBaseURL") ?? "https://api.openai.com/v1" }
        set { defaults.set(newValue, forKey: "llmBaseURL") }
    }

    static var llmAPIKey: String {
        get { defaults.string(forKey: "llmAPIKey") ?? "" }
        set { defaults.set(newValue, forKey: "llmAPIKey") }
    }

    static var llmModel: String {
        get { defaults.string(forKey: "llmModel") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "llmModel") }
    }
}
