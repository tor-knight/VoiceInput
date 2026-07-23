import Foundation

enum Preferences {
    // MARK: - Keychain Helper
    
    private enum Keychain {
        static let service = "com.voiceinput.app.apikey"
        
        static func save(key: String, value: String) {
            let data = value.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            
            SecItemDelete(query as CFDictionary)
            if !value.isEmpty {
                SecItemAdd(query as CFDictionary, nil)
            }
        }
        
        static func load(key: String) -> String? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var item: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
               let data = item as? Data {
                return String(data: data, encoding: .utf8)
            }
            return nil
        }
    }
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
        get { Keychain.load(key: "llmAPIKey") ?? "" }
        set { Keychain.save(key: "llmAPIKey", value: newValue) }
    }

    static var llmModel: String {
        get { defaults.string(forKey: "llmModel") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "llmModel") }
    }

    // MARK: - Sync (VPS)

    static var syncEnabled: Bool {
        get { defaults.bool(forKey: "syncEnabled") }
        set { defaults.set(newValue, forKey: "syncEnabled") }
    }

    static var syncVPSURL: String {
        get { defaults.string(forKey: "syncVPSURL") ?? "" }
        set { defaults.set(newValue, forKey: "syncVPSURL") }
    }

    static var syncAPIKey: String {
        get { Keychain.load(key: "syncAPIKey") ?? "" }
        set { Keychain.save(key: "syncAPIKey", value: newValue) }
    }

    // MARK: - Summary Prompt

    static let defaultSummaryPrompt = """
    你是一个专业的私人助理，负责根据我一天的碎片化语音输入，整理出我的核心工作和思考脉络。
    请阅读我今天所有的语音记录，忽略无意义的测试内容（如“喂喂喂”、“测试”），并使用 Markdown 格式输出一份结构化的日报。

    请严格按照以下格式组织：
    ### 📅 今日核心事件
    - [总结我今天主要做了什么、讨论了什么]

    ### 💡 零碎灵感与想法
    - [提取我语音中表达的新点子或思考]

    ### ✅ 潜在待办事项 (To-Do)
    - [提取我提到的未来需要做的事情]

    ### 💬 其他
    - [其他值得记录的内容]

    以下是我今天的语音记录：
    """

    static var summaryPrompt: String {
        get { defaults.string(forKey: "summaryPrompt") ?? defaultSummaryPrompt }
        set { defaults.set(newValue, forKey: "summaryPrompt") }
    }
}
