import Foundation

extension AppState {
    private enum Keys {
        static let mode = "mode"
        static let model = "model"
        static let language = "language"
        static let translateToEnglish = "translateToEnglish"
        static let output = "output"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let cancelKeyCode = "cancelKeyCode"
        static let cancelModifiers = "cancelModifiers"
        static let startSound = "startSound"
        static let stopSound = "stopSound"
        static let notifyOnComplete = "notifyOnComplete"
        static let promptContext = "promptContext"
        static let promptVocabulary = "promptVocabulary"
        static let promptStyle = "promptStyle"
        static let promptPunctuation = "promptPunctuation"
        static let promptInstructions = "promptExtra"
        static let replacementRules = "replacementRules"
        static let appToneRules = "appToneRules"  // legacy read-only key for migration
        static let tones = "tones"
        static let appRules = "appRules"
        static let defaultToneId = "defaultToneId"
        static let llmProvider = "llmProvider"
        static let llmModel = "llmModel"
        static let llmPostProcessEnabled = "llmPostProcessEnabled"
        static let llmStylePrompt = "llmStylePrompt"
        static let llmTranslateLanguage = "llmTranslateLanguage"
        static let history = "history"
        static let stats = "transcriptionStats"
        static let liveChunkInterval = "liveChunkInterval"
        static let liveOverlapMs = "liveOverlapMs"
        static let liveSilenceThreshold = "liveSilenceThreshold"
        static let liveSilenceTimeout = "liveSilenceTimeout"
        static let showFloatingWindow = "showFloatingWindow"
        static let appTheme = "appTheme"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let customReplacementCategories = "customReplacementCategories"
        static let uiLanguage = "uiLanguage"
    }

    private static let defaults = UserDefaults.standard

    func save() {
        Self.defaults.set(mode.rawValue, forKey: Keys.mode)
        Self.defaults.set(model.rawValue, forKey: Keys.model)
        Self.defaults.set(language.rawValue, forKey: Keys.language)
        Self.defaults.set(translateToEnglish, forKey: Keys.translateToEnglish)
        Self.defaults.set(outputMode.rawValue, forKey: Keys.output)
        Self.defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode)
        Self.defaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers)
        Self.defaults.set(Int(cancelKeyCode), forKey: Keys.cancelKeyCode)
        Self.defaults.set(Int(cancelModifiers), forKey: Keys.cancelModifiers)
        Self.defaults.set(startSound.rawValue, forKey: Keys.startSound)
        Self.defaults.set(stopSound.rawValue, forKey: Keys.stopSound)
        Self.defaults.set(notifyOnComplete, forKey: Keys.notifyOnComplete)
        Self.defaults.set(promptContext, forKey: Keys.promptContext)
        Self.defaults.set(promptVocabulary, forKey: Keys.promptVocabulary)
        Self.defaults.set(promptStyle, forKey: Keys.promptStyle)
        Self.defaults.set(promptPunctuation, forKey: Keys.promptPunctuation)
        Self.defaults.set(promptInstructions, forKey: Keys.promptInstructions)
        if let data = try? JSONEncoder().encode(replacementRules) {
            Self.defaults.set(data, forKey: Keys.replacementRules)
        }
        if let data = try? JSONEncoder().encode(customReplacementCategories) {
            Self.defaults.set(data, forKey: Keys.customReplacementCategories)
        }
        if let data = try? JSONEncoder().encode(tones) {
            Self.defaults.set(data, forKey: Keys.tones)
        }
        if let data = try? JSONEncoder().encode(appRules) {
            Self.defaults.set(data, forKey: Keys.appRules)
        }
        Self.defaults.set(defaultToneId?.uuidString, forKey: Keys.defaultToneId)
        Self.defaults.set(llmProvider.rawValue, forKey: Keys.llmProvider)
        Self.defaults.set(llmModel, forKey: Keys.llmModel)
        Self.defaults.set(llmPostProcessEnabled, forKey: Keys.llmPostProcessEnabled)
        Self.defaults.set(llmStylePrompt, forKey: Keys.llmStylePrompt)
        Self.defaults.set(llmTranslateLanguage?.rawValue ?? "", forKey: Keys.llmTranslateLanguage)
        if let data = try? JSONEncoder().encode(history) {
            Self.defaults.set(data, forKey: Keys.history)
        }
        if let data = try? JSONEncoder().encode(stats) {
            Self.defaults.set(data, forKey: Keys.stats)
        }
        Self.defaults.set(liveChunkInterval, forKey: Keys.liveChunkInterval)
        Self.defaults.set(liveOverlapMs, forKey: Keys.liveOverlapMs)
        Self.defaults.set(liveSilenceThreshold, forKey: Keys.liveSilenceThreshold)
        Self.defaults.set(liveSilenceTimeout, forKey: Keys.liveSilenceTimeout)
        Self.defaults.set(showFloatingWindow, forKey: Keys.showFloatingWindow)
        Self.defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        Self.defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        Self.defaults.set(uiLanguage, forKey: Keys.uiLanguage)
    }

    func restore() {
        if let rawMode = Self.defaults.string(forKey: Keys.mode),
           let restoredMode = TranscriptionMode(rawValue: rawMode) { mode = restoredMode }
        if let rawModel = Self.defaults.string(forKey: Keys.model),
           let restoredModel = WhisperModel(rawValue: rawModel) { model = restoredModel }
        if let rawLanguage = Self.defaults.string(forKey: Keys.language),
           let restoredLanguage = Language(rawValue: rawLanguage) { language = restoredLanguage }
        translateToEnglish = Self.defaults.bool(forKey: Keys.translateToEnglish)
        if let rawOutput = Self.defaults.string(forKey: Keys.output),
           let restoredOutput = OutputMode(rawValue: rawOutput) { outputMode = restoredOutput }
        if Self.defaults.object(forKey: Keys.hotkeyKeyCode) != nil {
            hotkeyKeyCode = UInt16(Self.defaults.integer(forKey: Keys.hotkeyKeyCode))
            hotkeyModifiers = UInt(Self.defaults.integer(forKey: Keys.hotkeyModifiers))
        }
        if Self.defaults.object(forKey: Keys.cancelKeyCode) != nil {
            cancelKeyCode = UInt16(Self.defaults.integer(forKey: Keys.cancelKeyCode))
            cancelModifiers = UInt(Self.defaults.integer(forKey: Keys.cancelModifiers))
        }
        if let rawStartSound = Self.defaults.string(forKey: Keys.startSound),
           let restoredStartSound = SoundEffect(rawValue: rawStartSound) { startSound = restoredStartSound }
        if let rawStopSound = Self.defaults.string(forKey: Keys.stopSound),
           let restoredStopSound = SoundEffect(rawValue: rawStopSound) { stopSound = restoredStopSound }
        notifyOnComplete = Self.defaults.bool(forKey: Keys.notifyOnComplete)
        if let restoredContext = Self.defaults.string(forKey: Keys.promptContext) { promptContext = restoredContext }
        if let restoredVocabulary = Self.defaults.string(forKey: Keys.promptVocabulary) { promptVocabulary = restoredVocabulary }
        if let restoredStyle = Self.defaults.string(forKey: Keys.promptStyle) { promptStyle = restoredStyle }
        if let restoredPunctuation = Self.defaults.string(forKey: Keys.promptPunctuation) { promptPunctuation = restoredPunctuation }
        if let restoredInstructions = Self.defaults.string(forKey: Keys.promptInstructions) { promptInstructions = restoredInstructions }
        if let data = Self.defaults.data(forKey: Keys.customReplacementCategories),
            let cats = try? JSONDecoder().decode([String].self, from: data) {
            customReplacementCategories = cats
        }
        if let data = Self.defaults.data(forKey: Keys.replacementRules),
           let restoredRules = try? JSONDecoder().decode([ReplacementRule].self, from: data) {
            replacementRules = restoredRules
        }
        if let data = Self.defaults.data(forKey: Keys.tones),
           let restoredTones = try? JSONDecoder().decode([AppTone].self, from: data) {
            tones = restoredTones
        }
        if let data = Self.defaults.data(forKey: Keys.appRules),
           let restoredRules = try? JSONDecoder().decode([AppRule].self, from: data) {
            appRules = restoredRules
        }
        if let raw = Self.defaults.string(forKey: Keys.defaultToneId) {
            defaultToneId = UUID(uuidString: raw)
        }
        // Migration: convert legacy appToneRules → tones + appRules
        if tones.isEmpty {
            if let data = Self.defaults.data(forKey: Keys.appToneRules),
               let oldRules = try? JSONDecoder().decode([AppToneRule].self, from: data), !oldRules.isEmpty {
                for rule in oldRules {
                    let tone = AppTone(name: rule.appName + (rule.urlPattern.isEmpty ? "" : " (\(rule.urlPattern))"), stylePrompt: rule.stylePrompt)
                    tones.append(tone)
                    appRules.append(AppRule(appName: rule.appName, urlPattern: rule.urlPattern, toneId: tone.id, isEnabled: rule.isEnabled))
                }
            }
            // Migrate global llmStylePrompt → default tone
            if !llmStylePrompt.isEmpty && defaultToneId == nil {
                let defaultTone = AppTone(name: "Default", stylePrompt: llmStylePrompt)
                tones.append(defaultTone)
                defaultToneId = defaultTone.id
            }
            // Seed built-in tones from StylePresets if still empty
            if tones.isEmpty {
                tones = StylePreset.allCases
                    .filter { $0 != .none }
                    .map { AppTone(name: $0.rawValue, stylePrompt: $0.prompt) }
            }
        }
        if let rawProvider = Self.defaults.string(forKey: Keys.llmProvider),
           let restoredProvider = LLMProvider(rawValue: rawProvider) { llmProvider = restoredProvider }
        if let restoredModel = Self.defaults.string(forKey: Keys.llmModel), !restoredModel.isEmpty {
            llmModel = restoredModel
        }
        if Self.defaults.object(forKey: Keys.llmPostProcessEnabled) != nil {
            llmPostProcessEnabled = Self.defaults.bool(forKey: Keys.llmPostProcessEnabled)
        }
        if let restoredStylePrompt = Self.defaults.string(forKey: Keys.llmStylePrompt) {
            llmStylePrompt = restoredStylePrompt
        }
        if let rawLang = Self.defaults.string(forKey: Keys.llmTranslateLanguage), !rawLang.isEmpty,
           let lang = Language(rawValue: rawLang) {
            llmTranslateLanguage = lang
        }
        if let data = Self.defaults.data(forKey: Keys.history),
           let restoredEntries = try? JSONDecoder().decode([TranscriptionEntry].self, from: data) {
            history = restoredEntries
        }
        if let data = Self.defaults.data(forKey: Keys.stats),
           let restoredStats = try? JSONDecoder().decode(TranscriptionStats.self, from: data) {
            stats = restoredStats
        }
        if Self.defaults.object(forKey: Keys.liveChunkInterval) != nil {
            liveChunkInterval = Self.defaults.double(forKey: Keys.liveChunkInterval)
        }
        if Self.defaults.object(forKey: Keys.liveOverlapMs) != nil {
            liveOverlapMs = Self.defaults.integer(forKey: Keys.liveOverlapMs)
        }
        if Self.defaults.object(forKey: Keys.liveSilenceThreshold) != nil {
            liveSilenceThreshold = Self.defaults.double(forKey: Keys.liveSilenceThreshold)
        }
        if Self.defaults.object(forKey: Keys.liveSilenceTimeout) != nil {
            liveSilenceTimeout = Self.defaults.double(forKey: Keys.liveSilenceTimeout)
        }
        if Self.defaults.object(forKey: Keys.showFloatingWindow) != nil {
            showFloatingWindow = Self.defaults.bool(forKey: Keys.showFloatingWindow)
        }
        if let rawTheme = Self.defaults.string(forKey: Keys.appTheme),
           let restoredTheme = AppTheme(rawValue: rawTheme) { appTheme = restoredTheme }
        if Self.defaults.object(forKey: Keys.hasCompletedOnboarding) != nil {
            hasCompletedOnboarding = Self.defaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        if let lang = Self.defaults.string(forKey: Keys.uiLanguage) { uiLanguage = lang }
    }
}
