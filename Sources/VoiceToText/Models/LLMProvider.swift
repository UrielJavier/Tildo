import Foundation

enum LLMProvider: String, CaseIterable, Codable {
    case claudeCode = "Claude Code"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case ollama = "Ollama"

    var baseURL: String {
        switch self {
        case .claudeCode: return ""
        case .openAI:     return "https://api.openai.com/v1/chat/completions"
        case .anthropic:  return "https://api.anthropic.com/v1/messages"
        case .groq:       return "https://api.groq.com/openai/v1/chat/completions"
        case .ollama:     return "http://localhost:11434/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .claudeCode: return "haiku"
        case .openAI:     return "gpt-4o-mini"
        case .anthropic:  return "claude-haiku-4-5-20251001"
        case .groq:       return "llama-3.1-8b-instant"
        case .ollama:     return "gemma4:e4b"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claudeCode:
            return ["haiku", "sonnet", "opus"]
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1"]
        case .anthropic:
            return [
                "claude-haiku-4-5-20251001",
                "claude-sonnet-4-5-20250514",
                "claude-sonnet-4-6",
                "claude-opus-4-7",
            ]
        case .groq:
            return ["llama-3.1-8b-instant", "llama-3.3-70b-versatile", "gemma2-9b-it"]
        case .ollama:
            return ["gemma4:e4b", "gemma4:e2b", "qwen3:4b", "qwen3:1.7b", "llama3.2:3b", "phi4-mini"]
        }
    }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code CLI"
        case .openAI:     return "OpenAI"
        case .anthropic:  return "Anthropic"
        case .groq:       return "Groq"
        case .ollama:     return "Ollama"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .claudeCode, .ollama: return false
        default: return true
        }
    }

    var keychainKey: String { "echowrite.llm.\(rawValue).apiKey" }
}
