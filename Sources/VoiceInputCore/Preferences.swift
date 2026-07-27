import Foundation
import Security

public enum Preferences {
    public static var useInMemoryKeychain = false
    private static var inMemoryKeychain: [String: String] = [:]

    // MARK: - Keychain Helper

    public enum Keychain {
        #if os(iOS)
        public static let service = "com.voiceinput.app.apikey"
        public static let accessGroup = "group.com.voiceinput.shared"
        #else
        public static let service = "com.voiceinput.app.apikey"
        #endif

        public static func save(key: String, value: String) {
            if useInMemoryKeychain {
                inMemoryKeychain[key] = value
                return
            }

            let data = value.data(using: .utf8)!
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            #if os(iOS)
            // Use access group for sharing between app and keyboard extension on iOS
            query[kSecAttrAccessGroup as String] = accessGroup
            #endif

            SecItemDelete(query as CFDictionary)
            if !value.isEmpty {
                SecItemAdd(query as CFDictionary, nil)
            }
        }

        public static func load(key: String) -> String? {
            if useInMemoryKeychain {
                return inMemoryKeychain[key]
            }

            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            #if os(iOS)
            query[kSecAttrAccessGroup as String] = accessGroup
            #endif

            var item: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
               let data = item as? Data {
                return String(data: data, encoding: .utf8)
            }
            return nil
        }
    }

    #if os(iOS)
    private static let defaults = UserDefaults(suiteName: "group.com.voiceinput.shared") ?? UserDefaults.standard
    #else
    private static let defaults = UserDefaults.standard
    #endif

    // MARK: - Language

    public enum Language: String, CaseIterable {
        case english           = "en-US"
        case simplifiedChinese = "zh-CN"
        case traditionalChinese = "zh-TW"
        case japanese          = "ja-JP"
        case korean            = "ko-KR"

        public var displayName: String {
            switch self {
            case .english:            return "English"
            case .simplifiedChinese:  return "简体中文"
            case .traditionalChinese: return "繁體中文"
            case .japanese:           return "日本語"
            case .korean:             return "한국어"
            }

        }
    }

    public static var selectedLanguage: Language {
        get {
            let raw = defaults.string(forKey: "selectedLanguage") ?? Language.simplifiedChinese.rawValue
            return Language(rawValue: raw) ?? .simplifiedChinese
        }
        set { defaults.set(newValue.rawValue, forKey: "selectedLanguage") }
    }

    // MARK: - LLM

    public enum LLMProvider: String, CaseIterable, Codable {
        case openai = "OpenAI"
        case gemini = "Google Gemini"
        case anthropic = "Anthropic Claude"
        case deepseek = "DeepSeek"
        case openrouter = "OpenRouter"
        case ollama = "Ollama (Local)"
        case custom = "Custom"

        public var defaultURL: String {
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

        public var defaultModel: String {
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

    public static var llmProvider: LLMProvider {
        get {
            let raw = defaults.string(forKey: "llmProvider") ?? LLMProvider.openai.rawValue
            return LLMProvider(rawValue: raw) ?? .openai
        }
        set { defaults.set(newValue.rawValue, forKey: "llmProvider") }
    }

    public static var llmEnabled: Bool {
        get { defaults.bool(forKey: "llmEnabled") }
        set { defaults.set(newValue, forKey: "llmEnabled") }
    }

    public static var llmBaseURL: String {
        get { defaults.string(forKey: "llmBaseURL") ?? "https://api.openai.com/v1" }
        set { defaults.set(newValue, forKey: "llmBaseURL") }
    }

    public static var llmAPIKey: String {
        get { Keychain.load(key: "llmAPIKey") ?? "" }
        set { Keychain.save(key: "llmAPIKey", value: newValue) }
    }

    public static var llmModel: String {
        get { defaults.string(forKey: "llmModel") ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: "llmModel") }
    }

    // MARK: - Sync (VPS)

    public static var syncEnabled: Bool {
        get { defaults.bool(forKey: "syncEnabled") }
        set { defaults.set(newValue, forKey: "syncEnabled") }
    }

    public static var syncVPSURL: String {
        get { defaults.string(forKey: "syncVPSURL") ?? "" }
        set { defaults.set(newValue, forKey: "syncVPSURL") }
    }

    public static var syncAPIKey: String {
        get { Keychain.load(key: "syncAPIKey") ?? "" }
        set { Keychain.save(key: "syncAPIKey", value: newValue) }
    }

    // MARK: - Summary Prompt

    public static let defaultSummaryPrompt = """
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

    public static var summaryPrompt: String {
        get { defaults.string(forKey: "summaryPrompt") ?? defaultSummaryPrompt }
        set { defaults.set(newValue, forKey: "summaryPrompt") }
    }
}
