import Foundation

actor TextPostProcessor {
    private let client = LLMClient()

    private static let systemPromptTemplate = """
    You are a text editor. Your ONLY task is to improve the following voice-transcribed text \
    according to the user's instructions below. Return ONLY the corrected text — no explanations, \
    no comments, no markdown formatting, no quotes around the text. \
    CRITICAL: Your response MUST be in the same language as the input text. \
    If the input is in Spanish, respond in Spanish. If in English, respond in English. \
    Never translate unless the user explicitly asks for it.

    Instructions:
    %@
    """

    private static let translationPromptTemplate = """
    You are a text editor and translator. Your task is to improve the following voice-transcribed text \
    and translate it to %@. Return ONLY the translated and corrected text — no explanations, \
    no comments, no markdown formatting, no quotes around the text.

    Instructions:
    %@
    """

    private static let defaultInstructions = """
    Fix punctuation (commas, periods, question marks, exclamation marks). \
    Maintain the original meaning and words as much as possible.
    """

    func warmUp(provider: LLMProvider, model: String) async {
        guard provider == .claudeCode, let path = LLMClient.findClaudeCLIPublic() else { return }
        await client.warmUp(claudePath: path, model: model)
    }

    func process(
        text: String,
        provider: LLMProvider,
        model: String,
        stylePrompt: String,
        translateTo: String? = nil
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }

        let apiKey: String
        if provider.requiresAPIKey {
            let key = KeychainHelper.load(key: provider.keychainKey) ?? ""
            guard !key.isEmpty else { return text }
            apiKey = key
        } else {
            apiKey = ""
        }

        let instructions = stylePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultInstructions
            : stylePrompt

        let systemPrompt: String
        if let targetLanguage = translateTo {
            systemPrompt = String(format: Self.translationPromptTemplate, targetLanguage, instructions)
        } else {
            systemPrompt = String(format: Self.systemPromptTemplate, instructions)
        }

        return try await client.process(
            text: text,
            systemPrompt: systemPrompt,
            provider: provider,
            apiKey: apiKey,
            model: model
        )
    }
}
