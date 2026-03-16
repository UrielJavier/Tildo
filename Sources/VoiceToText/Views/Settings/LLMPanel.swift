import SwiftUI

struct LLMPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var apiKey: String = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var selectedPreset: StylePreset = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("AI Text Enhancement",
                          subtitle: "Post-process transcriptions with an LLM to fix punctuation, adjust tone, or rephrase.")

            enableToggle
            if state.llmPostProcessEnabled {
                providerPicker
                modelPicker
                apiKeySection
                translateSection
                presetSection
                stylePromptSection
                testSection
            }
        }
        .padding(24)
        .onAppear {
            loadApiKey()
            selectedPreset = StylePreset.allCases.first { $0.prompt == state.llmStylePrompt && $0 != .none } ?? .none
        }
    }

    // MARK: - Subviews

    private var enableToggle: some View {
        settingsCard {
            Toggle(isOn: $state.llmPostProcessEnabled) {
                settingsRow("Enable AI post-processing", icon: "sparkles")
            }
            .toggleStyle(.switch)
            .onChange(of: state.llmPostProcessEnabled) { onSave() }
        }
    }

    private var providerPicker: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Provider").font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: $state.llmProvider) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: state.llmProvider) {
                    state.llmModel = state.llmProvider.defaultModel
                    loadApiKey()
                    onSave()
                }
            }
        }
    }

    private var modelPicker: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Model").font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: $state.llmModel) {
                    ForEach(state.llmProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: state.llmModel) { onSave() }
            }
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        if state.llmProvider.requiresAPIKey {
            settingsCard {
                HStack(spacing: 8) {
                    Image(systemName: "key")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("API Key").font(.callout.weight(.medium))
                }
                SecureField("Paste your \(state.llmProvider.rawValue) API key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                    .onChange(of: apiKey) {
                        KeychainHelper.save(key: state.llmProvider.keychainKey, value: apiKey)
                    }
                Text("Stored securely in your Mac's Keychain. Never leaves your device except to call the API.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            settingsCard {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text("Uses your Claude Code subscription — no API key needed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var translateSection: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Translate to").font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: translateLanguageBinding) {
                    Text("Off").tag(Optional<Language>.none)
                    Divider()
                    ForEach(Language.allCases.filter { $0 != .auto }, id: \.self) { lang in
                        Text(lang.label).tag(Optional<Language>.some(lang))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: state.llmTranslateLanguage) { onSave() }
            }
            Text("The AI will translate the transcription to the selected language. Requires AI post-processing to be enabled.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var translateLanguageBinding: Binding<Language?> {
        Binding(
            get: { state.llmTranslateLanguage },
            set: { state.llmTranslateLanguage = $0 }
        )
    }

    private var presetSection: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Style Preset").font(.callout.weight(.medium))
            }

            PresetGrid(selected: $selectedPreset) { preset in
                selectedPreset = preset
                if preset != .none {
                    state.llmStylePrompt = preset.prompt
                }
                onSave()
            }
        }
    }

    private var stylePromptSection: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Style Instructions").font(.callout.weight(.medium))
            }
            TextField(
                "e.g. Fix punctuation. Informal tone. Use \"tú\" instead of \"usted\".",
                text: $state.llmStylePrompt,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.callout)
            .lineLimit(2...6)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
            .onChange(of: state.llmStylePrompt) {
                if state.llmStylePrompt != selectedPreset.prompt {
                    selectedPreset = .none
                }
                onSave()
            }
            Text("Pick a preset above or write your own instructions. Leave empty for default punctuation fixes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var testSection: some View {
        settingsCard {
            HStack(spacing: 8) {
                Image(systemName: "play.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Test").font(.callout.weight(.medium))
                Spacer()
                Button {
                    runTest()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Run Test")
                    }
                }
                .disabled((state.llmProvider.requiresAPIKey && apiKey.isEmpty) || isTesting)
            }
            Text("Input: \"hola que tal como estas yo estoy bien y tu que haces hoy\"")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let testResult {
                TestResultView(result: testResult)
            }
        }
    }

    // MARK: - Logic

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
                await MainActor.run {
                    testResult = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Extracted subviews

private struct PresetGrid: View {
    @Binding var selected: StylePreset
    let onSelect: (StylePreset) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(StylePreset.allCases) { preset in
                PresetButton(preset: preset, isSelected: selected == preset) {
                    onSelect(preset)
                }
            }
        }
    }
}

private struct PresetButton: View {
    let preset: StylePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: preset.icon)
                    .font(.system(size: 11))
                Text(preset.rawValue)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TestResultView: View {
    let result: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: result.starts(with: "Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(result.starts(with: "Error") ? .red : .green)
                .font(.caption)
            Text(result)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
    }
}
