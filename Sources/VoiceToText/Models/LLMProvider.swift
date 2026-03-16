import Foundation

enum LLMProvider: String, CaseIterable, Codable {
    case claudeCode = "Claude Code"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"

    var baseURL: String {
        switch self {
        case .claudeCode: return ""
        case .openAI:     return "https://api.openai.com/v1/chat/completions"
        case .anthropic:  return "https://api.anthropic.com/v1/messages"
        case .groq:       return "https://api.groq.com/openai/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .claudeCode: return "haiku"
        case .openAI:     return "gpt-4o-mini"
        case .anthropic:  return "claude-haiku-4-5-20251001"
        case .groq:       return "llama-3.1-8b-instant"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claudeCode:
            return ["haiku", "sonnet", "opus"]
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1"]
        case .anthropic:
            return ["claude-haiku-4-5-20251001", "claude-sonnet-4-5-20250514"]
        case .groq:
            return ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "gemma2-9b-it"]
        }
    }

    var requiresAPIKey: Bool {
        self != .claudeCode
    }

    var keychainKey: String { "echowrite.llm.\(rawValue).apiKey" }
}
