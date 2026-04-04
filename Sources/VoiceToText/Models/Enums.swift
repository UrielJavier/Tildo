import AppKit

enum Language: String, CaseIterable {
    case auto = "auto"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"

    var label: String {
        switch self {
        case .auto:       return "Auto"
        case .english:    return "English"
        case .spanish:    return "Español"
        case .french:     return "Français"
        case .german:     return "Deutsch"
        case .italian:    return "Italiano"
        case .portuguese: return "Português"
        case .chinese:    return "中文"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .russian:    return "Русский"
        case .arabic:     return "العربية"
        case .hindi:      return "हिन्दी"
        case .dutch:      return "Nederlands"
        case .polish:     return "Polski"
        case .turkish:    return "Türkçe"
        }
    }
}

enum TranscriptionMode: String, CaseIterable {
    case live = "Live"
    case batch = "Batch"
}

enum OutputMode: String, CaseIterable {
    case typeText = "Type"
    case clipboard = "Clipboard"
}

enum SoundEffect: String, CaseIterable {
    case none = "None"
    case tink = "Tink"
    case pop = "Pop"
    case glass = "Glass"
    case ping = "Ping"
    case purr = "Purr"
    case morse = "Morse"
    case hero = "Hero"
    case funk = "Funk"
    case bottle = "Bottle"
    case blow = "Blow"
    case frog = "Frog"
    case basso = "Basso"
    case sosumi = "Sosumi"
    case submarine = "Submarine"

    func play() {
        guard self != .none else { return }
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

enum StylePreset: String, CaseIterable, Identifiable {
    case none = "Custom"
    case formal = "Formal"
    case elegant = "Elegant"
    case casual = "Casual"
    case friendly = "Friendly"
    case passive = "Passive-Aggressive"
    case concise = "Concise"
    case technical = "Technical"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none:       return "pencil"
        case .formal:     return "building.columns"
        case .elegant:    return "sparkle"
        case .casual:     return "cup.and.saucer"
        case .friendly:   return "face.smiling"
        case .passive:    return "theatermasks"
        case .concise:    return "scissors"
        case .technical:  return "wrench.and.screwdriver"
        }
    }

    var prompt: String {
        switch self {
        case .none:
            return ""
        case .formal:
            return "Rewrite in a formal, professional tone. Use proper grammar and polished language. Avoid contractions and colloquialisms."
        case .elegant:
            return "Rewrite with an elegant, sophisticated tone. Use refined vocabulary and graceful sentence structure. Aim for a literary quality."
        case .casual:
            return "Rewrite in a casual, relaxed tone. Use natural everyday language, contractions, and a conversational feel."
        case .friendly:
            return "Rewrite in a warm, friendly tone. Be approachable, positive, and kind. Make the reader feel welcome."
        case .passive:
            return "Rewrite in a passive-aggressive tone. Be polite on the surface but subtly sarcastic. Use phrases like \"as per my last message\" or \"just to clarify\"."
        case .concise:
            return "Make the text as concise as possible. Remove filler words, redundancy, and unnecessary detail. Keep only the essential meaning."
        case .technical:
            return "Rewrite in a precise, technical tone. Use clear and unambiguous language. Prefer specificity over generality."
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case models = "Models"
    case transcription = "Transcription"
    case replacements = "Replacements"
    case llm = "AI Enhance"
    case tones = "Tones"
    case appRules = "App Rules"
    case dashboard = "Metrics"
    case history = "History"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:       return "gearshape"
        case .appearance:    return "paintbrush"
        case .models:        return "cube.box"
        case .transcription: return "waveform"
        case .replacements:  return "arrow.2.squarepath"
        case .llm:           return "sparkles"
        case .tones:         return "music.note.list"
        case .appRules:      return "app.badge"
        case .dashboard:     return "chart.bar"
        case .history:       return "clock.arrow.circlepath"
        case .about:         return "info.circle"
        }
    }
}
