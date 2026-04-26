import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Status: String {
        case idle = "Ready"
        case recording = "Recording..."
        case transcribing = "Transcribing..."
        case processing = "Enhancing..."
        case done = "Done"
        case error = "Error"
    }

    var status: Status = .idle
    var lastError: String?
    var hasCompletedOnboarding: Bool = false
    var uiLanguage: String = "system"

    var resolvedLocale: Locale {
        switch uiLanguage {
        case "en": return Locale(identifier: "en")
        case "es": return Locale(identifier: "es")
        default:   return Locale.current
        }
    }
    var isModelLoaded = false
    var isLoadingModel = false
    var language: Language = .auto
    var translateToEnglish = false  // legacy, kept for history entries
    var llmTranslateLanguage: Language?
    var mode: TranscriptionMode = .batch
    var model: WhisperModel = .largeV3TurboQ5
    var outputMode: OutputMode = .typeText
    var hotkeyKeyCode: UInt16 = 1
    var hotkeyModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue
    var cancelKeyCode: UInt16 = UInt16.max   // UInt16.max = not assigned
    var cancelModifiers: UInt = 0
    var triggerMode: TriggerMode = .tapToToggle
    var showInDock: Bool = false
    var startSound: SoundEffect = .pop
    var stopSound: SoundEffect = .funk
    var notifyOnComplete = false
    var showFloatingWindow = true
    var appTheme: AppTheme = .light

    // Prompt fields — composed into initial_prompt for whisper
    var promptContext: String = ""
    var promptVocabulary: String = ""
    var promptStyle: String = "Natural, conversacional"
    var promptPunctuation: String = "Usar puntuación correcta: comas, puntos, signos de interrogación"
    var promptInstructions: String = "Ignorar ruido de fondo y silencios"

    // LLM post-processing
    var llmProvider: LLMProvider = .claudeCode
    var llmModel: String = LLMProvider.claudeCode.defaultModel
    var llmPostProcessEnabled: Bool = false
    var llmStylePrompt: String = ""

    // Text replacement rules applied after transcription
    var replacementRules: [ReplacementRule] = ReplacementRule.defaultRules
    var customReplacementCategories: [String] = []

    // Tone library + per-app rules
    var tones: [AppTone] = []
    var appRules: [AppRule] = []
    var defaultToneId: UUID? = nil

    // Legacy — kept for data migration from older versions. Not shown in UI.
    var appToneRules: [AppToneRule] = []

    // Transient UI — not persisted
    var ruleAddOpen: Bool = false
    var ruleEditing: AppRule? = nil
    var toneAddOpen: Bool = false
    var toneEditing: AppTone? = nil
    var activeToneNameForRecording: String? = nil  // set at recording start, shown in floating pill

    /// Resolves the style prompt for a given app + URL.
    /// Precedence: per-app URL rule > per-app rule > default tone > llmStylePrompt (legacy fallback).
    func resolveStylePrompt(appName: String, url: String?) -> String {
        let enabled = appRules.filter {
            $0.isEnabled && $0.appName.lowercased() == appName.lowercased()
        }
        let matchedId: UUID?
        if let url, let urlRule = enabled.first(where: {
            !$0.urlPattern.isEmpty && url.lowercased().contains($0.urlPattern.lowercased())
        }) {
            matchedId = urlRule.toneId
        } else if let appRule = enabled.first(where: { $0.urlPattern.isEmpty }) {
            matchedId = appRule.toneId
        } else {
            matchedId = defaultToneId
        }
        if let id = matchedId, let tone = tones.first(where: { $0.id == id }) {
            return tone.stylePrompt
        }
        return llmStylePrompt
    }

    func applyReplacements(_ text: String) -> String {
        var result = text
        for rule in replacementRules where rule.enabled && !rule.find.isEmpty {
            result = result.replacingOccurrences(
                of: rule.find, with: rule.replace,
                options: .caseInsensitive
            )
        }
        return result
    }

    var composedPrompt: String {
        var parts: [String] = []
        let fields: [(String, String)] = [
            ("Contexto", promptContext),
            ("Vocabulario", promptVocabulary),
            ("Estilo", promptStyle),
            ("Puntuación", promptPunctuation),
            ("Instrucciones", promptInstructions),
        ]
        for (heading, value) in fields {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { parts.append("# \(heading)\n\(trimmed)") }
        }
        return parts.joined(separator: "\n\n")
    }

    // Live mode tuning
    var liveChunkInterval: Double = 2.0      // seconds between transcriptions
    var liveOverlapMs: Int = 500             // ms of audio kept for context between chunks
    var liveSilenceThreshold: Double = 0.002 // energy below this = silence
    var liveSilenceTimeout: Double = 10.0    // seconds of silence before auto-stop

    var recordingSeconds: Int = 0
    var audioLevel: Float = 0  // 0.0 to 1.0, updated during recording
    var silenceCountdown: Int = 0  // seconds until auto-stop, 0 = not counting

    var modelListVersion = 0
    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadingModel: WhisperModel?
    var history: [TranscriptionEntry] = []
    var stats = TranscriptionStats()
    var selectedSettingsSection: SettingsSection = .general
    var selectedMainSection: MainSection = .inicio
    var showSettings: Bool = false

    var hotkeyLabel: String {
        VoiceToText.hotkeyLabel(keyCode: hotkeyKeyCode, modifiers: NSEvent.ModifierFlags(rawValue: hotkeyModifiers))
    }

    func addToHistory(_ text: String, rawText: String? = nil, durationSeconds: Int = 0, translated: Bool = false) {
        let trimmed = applyReplacements(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let wc = trimmed.split(whereSeparator: \.isWhitespace).count
        let rawTrimmed = rawText.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let entry = TranscriptionEntry(
            text: trimmed,
            rawText: rawTrimmed != trimmed ? rawTrimmed : nil,
            durationSeconds: durationSeconds,
            wordCount: wc,
            mode: mode.rawValue,
            wasTranslated: translated
        )
        history.insert(entry, at: 0)
        if history.count > 50 { history.removeLast() }
        stats.record(seconds: durationSeconds, text: trimmed, translated: translated)
        save()
    }

    func resetToDefaults() {
        language = .auto
        translateToEnglish = false
        llmTranslateLanguage = nil
        mode = .batch
        model = .largeV3TurboQ5
        outputMode = .typeText
        hotkeyKeyCode = 1
        hotkeyModifiers = NSEvent.ModifierFlags([.command, .function]).rawValue
        cancelKeyCode = UInt16.max
        cancelModifiers = 0
        triggerMode = .tapToToggle
        showInDock = false
        startSound = .pop
        stopSound = .funk
        notifyOnComplete = false
        showFloatingWindow = true
        appTheme = .light
        promptContext = ""
        promptVocabulary = ""
        promptStyle = "Natural, conversacional"
        promptPunctuation = "Usar puntuación correcta: comas, puntos, signos de interrogación"
        promptInstructions = "Ignorar ruido de fondo y silencios"
        replacementRules = ReplacementRule.defaultRules
        tones = []
        appRules = []
        defaultToneId = nil
        llmProvider = .claudeCode
        llmModel = LLMProvider.claudeCode.defaultModel
        llmPostProcessEnabled = false
        llmStylePrompt = ""
        liveChunkInterval = 2.0
        liveOverlapMs = 500
        liveSilenceThreshold = 0.002
        liveSilenceTimeout = 10.0
    }

    var isRecording: Bool { status == .recording }
    var isTranscribing: Bool { status == .transcribing }

    var isProcessing: Bool { status == .processing }

    var statusIcon: String {
        switch status {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "text.bubble"
        case .processing: return "sparkles"
        case .done: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}
