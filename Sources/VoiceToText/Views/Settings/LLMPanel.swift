import SwiftUI

struct LLMPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var apiKey: String = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHero(icon: "sparkles", title: "AI Enhance", subtitle: "Post-process transcriptions with an LLM to fix punctuation, adjust tone, or rephrase.")

            enableToggle
            if state.llmPostProcessEnabled {
                providerPicker
                modelPicker
                apiKeySection
                translateSection
                testSection
            }
        }
        .padding(24)
        .onAppear { loadApiKey() }
    }

    private var enableToggle: some View {
        settingsCard {
            DSToggle(title: "Enable AI post-processing", icon: "sparkles", isOn: $state.llmPostProcessEnabled)
                .onChange(of: state.llmPostProcessEnabled) { onSave() }
        }
    }

    private var providerPicker: some View {
        settingsCard {
            HStack {
                settingsRow("Provider", icon: "server.rack")
                Spacer()
                Menu {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Button(provider.rawValue) {
                            state.llmProvider = provider
                            state.llmModel = state.llmProvider.defaultModel
                            loadApiKey()
                            onSave()
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.llmProvider.rawValue)
                            .font(DS.Fonts.sans(13))
                            .foregroundStyle(DS.Colors.charcoalWarm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Colors.stoneGray)
                    }
                    .dsMenuLabel()
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var modelPicker: some View {
        settingsCard {
            HStack {
                settingsRow("Model", icon: "cpu")
                Spacer()
                Menu {
                    ForEach(state.llmProvider.availableModels, id: \.self) { model in
                        Button(model) { state.llmModel = model; onSave() }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.llmModel)
                            .font(DS.Fonts.sans(13))
                            .foregroundStyle(DS.Colors.charcoalWarm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Colors.stoneGray)
                    }
                    .dsMenuLabel()
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        if state.llmProvider.requiresAPIKey {
            settingsCard {
                settingsRow("API Key", icon: "key")
                SecureField("Paste your \(state.llmProvider.rawValue) API key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(DS.Fonts.sans(14))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Colors.warmSand.opacity(0.6))
                    )
                    .onChange(of: apiKey) {
                        KeychainHelper.save(key: state.llmProvider.keychainKey, value: apiKey)
                    }
                Text("Stored securely in your Mac's Keychain. Never leaves your device except to call the API.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }
        } else {
            settingsCard {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .frame(width: 18)
                    Text("Uses your Claude Code subscription — no API key needed.")
                        .font(DS.Fonts.sans(14))
                        .foregroundStyle(DS.Colors.oliveGray)
                }
            }
        }
    }

    private var translateSection: some View {
        settingsCard {
            HStack {
                settingsRow("Translate to", icon: "character.book.closed")
                Spacer()
                Menu {
                    Button("Off") { state.llmTranslateLanguage = nil; onSave() }
                    Divider()
                    ForEach(Language.allCases.filter { $0 != .auto }, id: \.self) { lang in
                        Button(lang.label) { state.llmTranslateLanguage = lang; onSave() }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.llmTranslateLanguage?.label ?? "Off")
                            .font(DS.Fonts.sans(13))
                            .foregroundStyle(DS.Colors.charcoalWarm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Colors.stoneGray)
                    }
                    .dsMenuLabel()
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            Text("The AI will translate the transcription to the selected language. Requires AI post-processing to be enabled.")
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.stoneGray)
        }
    }

    private var testSection: some View {
        settingsCard {
            HStack {
                settingsRow("Test", icon: "play.circle")
                Spacer()
                Button {
                    runTest()
                } label: {
                    if isTesting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Text("Run Test")
                    }
                }
                .buttonStyle(.dsSecondary)
                .disabled((state.llmProvider.requiresAPIKey && apiKey.isEmpty) || isTesting)
            }
            Text("Input: \"hola que tal como estas yo estoy bien y tu que haces hoy\"")
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.stoneGray)

            if let testResult {
                TestResultView(result: testResult)
            }
        }
    }

    private func loadApiKey() {
        apiKey = KeychainHelper.load(key: state.llmProvider.keychainKey) ?? ""
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        let provider = state.llmProvider
        let model = state.llmModel
        let stylePrompt = state.llmStylePrompt
        let translateTo = state.llmTranslateLanguage?.label

        Task {
            let processor = TextPostProcessor()
            do {
                let result = try await processor.process(
                    text: "hola que tal como estas yo estoy bien y tu que haces hoy",
                    provider: provider,
                    model: model,
                    stylePrompt: stylePrompt,
                    translateTo: translateTo
                )
                await MainActor.run { testResult = result; isTesting = false }
            } catch {
                await MainActor.run { testResult = "Error: \(error.localizedDescription)"; isTesting = false }
            }
        }
    }
}

private struct TestResultView: View {
    let result: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: result.starts(with: "Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(result.starts(with: "Error") ? Color(hex: "b53333") : .green)
                .font(.caption)
            Text(result)
                .font(DS.Fonts.sans(12))
                .foregroundStyle(DS.Colors.oliveGray)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(DS.Colors.warmSand.opacity(0.5))
        )
    }
}
