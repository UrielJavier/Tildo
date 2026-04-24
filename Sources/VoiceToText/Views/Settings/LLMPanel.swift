import SwiftUI

// MARK: - Panel

struct LLMPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    @State private var anthropicKey = ""
    @State private var openAIKey = ""
    @State private var anthropicModel = LLMProvider.anthropic.defaultModel
    @State private var openAIModel = LLMProvider.openAI.defaultModel
    @State private var cliModel = LLMProvider.claudeCode.defaultModel
    @State private var openModelDropdown: LLMProvider? = nil
    @State private var testingProvider: LLMProvider? = nil
    @State private var showKeyProvider: LLMProvider? = nil
    @State private var showKeyTimer: Task<Void, Never>? = nil
    @State private var cliPath: String? = nil
    @State private var toast: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    private var activeProvider: LLMProvider? {
        state.llmPostProcessEnabled ? state.llmProvider : nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock
                    statusBanner.padding(.top, 16)
                    providerCards.padding(.top, 18)
                    privacyFooter.padding(.top, 16).padding(.bottom, 8)
                }
                .padding(24)
            }
            if let msg = toast {
                LLMToast(message: msg)
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast != nil)
        .onAppear { loadKeys() }
    }

    // MARK: - Header

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LLM")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Colors.ink)
            Text("Tones use an LLM to transform your dictation. You can dictate with or without it, but without an LLM there are no tone transformations.")
                .font(DS.Fonts.sans(12.5))
                .foregroundStyle(DS.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if let active = activeProvider {
            HStack(spacing: 8) {
                Circle().fill(DS.Colors.moss).frame(width: 7, height: 7)
                (Text("Active: ").bold() + Text(bannerLabel(active)))
                    .font(DS.Fonts.sans(12.5))
                    .foregroundStyle(DS.Colors.mossInk)
                Spacer()
                Button("Change") { deactivate() }
                    .buttonStyle(LLMGhostButton())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(DS.Colors.mossSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "DCE4CC"), lineWidth: 1))
        } else {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(DS.Colors.ink4).frame(width: 7, height: 7).padding(.top, 4)
                (Text("No LLM configured.").bold() +
                 Text(" Tildo dictates with Whisper just fine. Choose a provider to enable tones."))
                    .font(DS.Fonts.sans(12.5))
                    .foregroundStyle(DS.Colors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(DS.Colors.line)
            )
        }
    }

    private func bannerLabel(_ provider: LLMProvider) -> String {
        switch provider {
        case .claudeCode: return "Claude Code CLI · local session"
        case .anthropic:  return "Anthropic · \(state.llmModel.isEmpty ? "Claude Haiku 4.5" : state.llmModel)"
        case .openAI:     return "OpenAI · \(state.llmModel.isEmpty ? "GPT-4o mini" : state.llmModel)"
        case .groq:       return "Groq · \(state.llmModel)"
        }
    }

    // MARK: - Cards

    private var providerCards: some View {
        VStack(spacing: 10) {
            cliCard
                .zIndex(openModelDropdown == .claudeCode ? 3 : 1)
            apiCard(
                provider: .anthropic,
                logo: LLMProviderLogo(symbol: "A", bg: Color(hex: "1a1a1a"), fg: Color(hex: "c96442")),
                tagline: "Fast, natural, great translation. Recommended.",
                selectedModel: $anthropicModel,
                keyBinding: $anthropicKey,
                placeholder: "sk-ant-…"
            )
            .zIndex(openModelDropdown == .anthropic ? 3 : 1)
            apiCard(
                provider: .openAI,
                logo: LLMProviderLogo(symbol: "⊕", bg: Color(hex: "1a1a1a"), fg: .white),
                tagline: "Widely used. If you already have an account, this fits well.",
                selectedModel: $openAIModel,
                keyBinding: $openAIKey,
                placeholder: "sk-proj-…"
            )
            .zIndex(openModelDropdown == .openAI ? 3 : 1)
        }
    }

    // MARK: - API provider card

    @ViewBuilder
    private func apiCard(
        provider: LLMProvider,
        logo: LLMProviderLogo,
        tagline: String,
        selectedModel: Binding<String>,
        keyBinding: Binding<String>,
        placeholder: String
    ) -> some View {
        let isActive = activeProvider == provider
        let isTesting = testingProvider == provider
        let dimmed = testingProvider != nil && testingProvider != provider

        LLMCardShell(isActive: isActive, dimmed: dimmed) {
            VStack(alignment: .leading, spacing: 12) {
                // Top info row
                HStack(alignment: .top, spacing: 12) {
                    logo
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(provider.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(DS.Colors.ink)
                            if isActive { LLMActiveBadge() }
                        }
                        Text(tagline)
                            .font(DS.Fonts.sans(12.5))
                            .foregroundStyle(DS.Colors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                // Model picker — zIndex(1) ensures dropdown renders above subsequent siblings (API key row)
                LLMModelPicker(
                    provider: provider,
                    selected: selectedModel,
                    disabled: isTesting,
                    isOpen: Binding(
                        get: { openModelDropdown == provider },
                        set: { openModelDropdown = $0 ? provider : nil }
                    )
                )
                .zIndex(1)
                // Action row
                if isTesting {
                    LLMTestingRow(maskedKey: maskEnd(keyBinding.wrappedValue))
                } else if isActive {
                    LLMActiveKeyRow(
                        rawKey: KeychainHelper.load(key: provider.keychainKey) ?? keyBinding.wrappedValue,
                        showFull: showKeyProvider == provider,
                        onShow: { toggleShowKey(provider) },
                        onChangeKey: { deactivateAndClearKey(provider, binding: keyBinding) }
                    )
                } else {
                    LLMIdleKeyRow(
                        key: keyBinding,
                        placeholder: placeholder,
                        onActivate: { Task { await activate(provider, key: keyBinding.wrappedValue, model: selectedModel.wrappedValue) } }
                    )
                }
            }
        }
    }

    // MARK: - CLI card

    private var cliCard: some View {
        let isActive = activeProvider == .claudeCode
        let isTesting = testingProvider == .claudeCode
        let dimmed = testingProvider != nil && !isTesting

        return LLMCardShell(isActive: isActive, dimmed: dimmed) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    LLMProviderLogo(symbol: ">_", bg: Color(hex: "1a1a1a"), fg: DS.Colors.moss)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Claude Code CLI")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(DS.Colors.ink)
                            LLMNoAPIKeyBadge()
                            if isActive { LLMActiveBadge() }
                        }
                        Text("Tu sesión local de `claude`")
                            .font(DS.Fonts.mono(11))
                            .foregroundStyle(DS.Colors.ink3)
                        Text("Si ya usas Claude Code en el terminal, Tildo reusa esa sesión. Sin API keys, sin coste adicional.")
                            .font(DS.Fonts.sans(12.5))
                            .foregroundStyle(DS.Colors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                }
                LLMModelPicker(
                    provider: .claudeCode,
                    selected: $cliModel,
                    disabled: isTesting,
                    isOpen: Binding(
                        get: { openModelDropdown == .claudeCode },
                        set: { openModelDropdown = $0 ? .claudeCode : nil }
                    )
                )
                .zIndex(1)
                if isTesting {
                    LLMTestingRow(maskedKey: nil)
                } else if isActive {
                    LLMCLIActiveRow(path: cliPath ?? "") {
                        Task { await testCLI() }
                    } onDeactivate: {
                        deactivate()
                    }
                } else {
                    LLMCLIIdleRow { Task { await detectCLI() } }
                }
            }
        }
    }

    // MARK: - Translate card

    private var translateCard: some View {
        settingsCard {
            HStack {
                settingsRow("Translate to", icon: "character.book.closed")
                Spacer()
                Menu {
                    Button("Desactivado") { state.llmTranslateLanguage = nil; onSave() }
                    Divider()
                    ForEach(Language.allCases.filter { $0 != .auto }, id: \.self) { lang in
                        Button(lang.label) { state.llmTranslateLanguage = lang; onSave() }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.llmTranslateLanguage?.label ?? "Desactivado")
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

    // MARK: - Footer

    private var privacyFooter: some View {
        Text("Tildo only sends the transcribed text and the tone prompt. Never sends audio.")
            .font(DS.Fonts.sans(11.5))
            .foregroundStyle(DS.Colors.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func loadKeys() {
        anthropicKey = KeychainHelper.load(key: LLMProvider.anthropic.keychainKey) ?? ""
        openAIKey = KeychainHelper.load(key: LLMProvider.openAI.keychainKey) ?? ""
        if activeProvider == .anthropic, !state.llmModel.isEmpty { anthropicModel = state.llmModel }
        if activeProvider == .openAI, !state.llmModel.isEmpty { openAIModel = state.llmModel }
        if activeProvider == .claudeCode, !state.llmModel.isEmpty { cliModel = state.llmModel }
        if activeProvider == .claudeCode { cliPath = findCLIBinary() }
    }

    private func activate(_ provider: LLMProvider, key: String, model: String) async {
        guard !key.isEmpty else { return }
        testingProvider = provider
        KeychainHelper.save(key: provider.keychainKey, value: key)
        do {
            let processor = TextPostProcessor()
            _ = try await processor.process(
                text: "ping",
                provider: provider,
                model: model,
                stylePrompt: "Reply with exactly: pong",
                translateTo: nil
            )
            state.llmProvider = provider
            state.llmModel = model
            state.llmPostProcessEnabled = true
            testingProvider = nil
            onSave()
        } catch {
            KeychainHelper.delete(key: provider.keychainKey)
            testingProvider = nil
            showToast(toastMessage(error, provider: provider))
        }
    }

    private func deactivate() {
        state.llmPostProcessEnabled = false
        testingProvider = nil
        onSave()
    }

    private func deactivateAndClearKey(_ provider: LLMProvider, binding: Binding<String>) {
        KeychainHelper.delete(key: provider.keychainKey)
        binding.wrappedValue = ""
        deactivate()
    }

    private func detectCLI() async {
        testingProvider = .claudeCode
        try? await Task.sleep(nanoseconds: 600_000_000)
        if let path = findCLIBinary() {
            cliPath = path
            state.llmProvider = .claudeCode
            state.llmModel = cliModel
            state.llmPostProcessEnabled = true
            testingProvider = nil
            onSave()
        } else {
            testingProvider = nil
            showToast("No se encontró `claude` en tu PATH. Instala Claude Code desde claude.com/code.")
        }
    }

    private func testCLI() async {
        testingProvider = .claudeCode
        do {
            let processor = TextPostProcessor()
            _ = try await processor.process(
                text: "ping",
                provider: .claudeCode,
                model: cliModel,
                stylePrompt: "Reply with exactly: pong",
                translateTo: nil
            )
            testingProvider = nil
            showToast(String(localized: "Claude Code CLI connection successful."))
        } catch {
            testingProvider = nil
            showToast(toastMessage(error, provider: .claudeCode))
        }
    }

    private func findCLIBinary() -> String? {
        let known = ["/usr/local/bin/claude", "/opt/homebrew/bin/claude",
                     "\(NSHomeDirectory())/.local/bin/claude"]
        if let found = known.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }
        let task = Process(); let pipe = Pipe()
        task.launchPath = "/usr/bin/which"; task.arguments = ["claude"]
        task.standardOutput = pipe; task.standardError = Pipe()
        try? task.run(); task.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return out.isEmpty ? nil : out
    }

    private func toggleShowKey(_ provider: LLMProvider) {
        if showKeyProvider == provider {
            showKeyProvider = nil
            showKeyTimer?.cancel()
        } else {
            showKeyTimer?.cancel()
            showKeyProvider = provider
            showKeyTimer = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                showKeyProvider = nil
            }
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            toast = nil
        }
    }

    private func maskEnd(_ key: String) -> String {
        guard key.count > 4 else { return String(repeating: "•", count: key.count) }
        return String(repeating: "•", count: max(0, key.count - 4)) + key.suffix(4)
    }

    private func toastMessage(_ error: Error, provider: LLMProvider) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("401") || msg.contains("unauthorized") || msg.contains("invalid") {
            return String(format: String(localized: "The key is not valid. Check that it is an active key from %@."), provider.displayName)
        } else if msg.contains("429") {
            return "\(provider.displayName) returned 429. Wait a few seconds."
        } else if msg.contains("network") || msg.contains("connect") || msg.contains("offline") || msg.contains("timed out") {
            return String(format: String(localized: "Could not connect to %@. Check your connection."), provider.displayName)
        }
        return String(format: String(localized: "Something failed.") + " %@", error.localizedDescription)
    }
}

// MARK: - Model picker

private struct LLMModelPicker: View {
    let provider: LLMProvider
    @Binding var selected: String
    let disabled: Bool
    @Binding var isOpen: Bool

    @FocusState private var fieldFocused: Bool

    var body: some View {
        TildoDropdown(
            items: provider.availableModels,
            isOpen: $isOpen,
            triggerHeight: 47,
            onSelect: { selected = $0 },
            onClose: { fieldFocused = false },
            maxListHeight: 180
        ) {
            pickerField
        } row: { model, isHighlighted in
            TildoDropdownMonoRow(label: model, isHighlighted: isHighlighted, isSelected: selected == model)
        }
        .opacity(disabled ? 0.5 : 1)
        .allowsHitTesting(!disabled)
    }

    private var pickerField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("MODELO")
                .font(DS.Fonts.mono(10))
                .foregroundStyle(DS.Colors.ink4)
                .tracking(0.3)
            HStack(spacing: 4) {
                TextField("model-id…", text: $selected)
                    .textFieldStyle(.plain)
                    .font(DS.Fonts.mono(11))
                    .foregroundStyle(DS.Colors.ink)
                    .focused($fieldFocused)
                    .onChange(of: fieldFocused) { _, focused in
                        if focused && !disabled { isOpen = true }
                    }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(DS.Colors.ink3)
                    .rotationEffect(isOpen ? .degrees(180) : .zero)
                    .animation(.easeInOut(duration: 0.15), value: isOpen)
                    .padding(.trailing, 10)
                    .onTapGesture { if !disabled { isOpen.toggle() } }
            }
            .frame(height: 30)
            .padding(.leading, 10)
            .background(DS.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isOpen ? DS.Colors.ink3 : DS.Colors.lineSoft, lineWidth: 1))
        }
    }
}

// MARK: - Card shell

private struct LLMCardShell<Content: View>: View {
    let isActive: Bool
    let dimmed: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Background handles the visual shape; no clipShape so child overlays (dropdowns) can overflow
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(isActive ? Color(hex: "F5F8EE") : DS.Colors.card)
                .shadow(color: isActive ? Color(hex: "4F6F3A").opacity(0.08) : .clear, radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .strokeBorder(isActive ? DS.Colors.moss : DS.Colors.line, lineWidth: 1)
                )
        )
        .opacity(dimmed ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: dimmed)
    }
}

// MARK: - Provider logo

private struct LLMProviderLogo: View {
    let symbol: String
    let bg: Color
    let fg: Color

    var body: some View {
        Text(symbol)
            .font(.system(size: symbol.count > 1 ? 12 : 16, weight: .semibold))
            .foregroundStyle(fg)
            .frame(width: 36, height: 36)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Badges

private struct LLMActiveBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(DS.Colors.moss).frame(width: 6, height: 6)
            Text("ACTIVE")
                .font(DS.Fonts.mono(10, weight: .medium))
                .foregroundStyle(DS.Colors.mossInk)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct LLMNoAPIKeyBadge: View {
    var body: some View {
        Text("NO API KEY")
            .font(DS.Fonts.mono(9, weight: .medium))
            .foregroundStyle(DS.Colors.paper)
            .tracking(0.4)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(DS.Colors.moss)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Action rows

private struct LLMIdleKeyRow: View {
    @Binding var key: String
    let placeholder: String
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("API KEY")
                .font(DS.Fonts.mono(10.5))
                .foregroundStyle(DS.Colors.ink3)
                .tracking(0.3)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .fixedSize()

            SecureField(placeholder, text: $key)
                .textFieldStyle(.plain)
                .font(DS.Fonts.mono(12))
                .foregroundStyle(DS.Colors.ink)
                .frame(maxWidth: .infinity)

            Button("Activate") { onActivate() }
                .buttonStyle(LLMActivateButton())
                .disabled(key.isEmpty)
                .padding(.trailing, 6)
        }
        .frame(height: 38)
        .background(DS.Colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.lineSoft, lineWidth: 1))
    }
}

private struct LLMActiveKeyRow: View {
    let rawKey: String
    let showFull: Bool
    let onShow: () -> Void
    let onChangeKey: () -> Void

    private var displayKey: String {
        guard !rawKey.isEmpty else { return "••••••••••••••••" }
        if showFull { return rawKey }
        let prefix = String(rawKey.prefix(10))
        let suffix = String(rawKey.suffix(3))
        let dots = String(repeating: "•", count: max(0, rawKey.count - 13))
        return "\(prefix)\(dots)\(suffix)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("KEY")
                .font(DS.Fonts.mono(10.5))
                .foregroundStyle(DS.Colors.ink3)
                .tracking(0.3)
                .padding(.leading, 12)
                .fixedSize()

            Text(displayKey)
                .font(DS.Fonts.mono(11.5))
                .foregroundStyle(DS.Colors.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)

            Button("Show") { onShow() }
                .buttonStyle(.plain)
                .font(DS.Fonts.sans(11.5))
                .foregroundStyle(DS.Colors.ink3)

            Button("Change") { onChangeKey() }
                .buttonStyle(LLMGhostButton())
                .padding(.trailing, 6)
        }
        .frame(height: 38)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(hex: "DCE4CC"), lineWidth: 1))
    }
}

private struct LLMTestingRow: View {
    let maskedKey: String?
    @State private var rotating = false

    var body: some View {
        HStack(spacing: 10) {
            Text("∼")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        rotating = true
                    }
                }
            Text("TESTING CONNECTION…")
                .font(DS.Fonts.mono(11))
                .foregroundStyle(DS.Colors.mossInk)
                .tracking(0.3)
            Spacer()
            if let key = maskedKey {
                Text(key)
                    .font(DS.Fonts.mono(11))
                    .foregroundStyle(DS.Colors.ink3)
            }
        }
        .frame(height: 38)
        .padding(.horizontal, 12)
        .background(DS.Colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.lineSoft, lineWidth: 1))
    }
}

private struct LLMCLIIdleRow: View {
    let onDetect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.ink4)
            Group {
                Text("Tildo detectará ") +
                Text("`claude`").font(DS.Fonts.mono(11)) +
                Text(" en tu PATH y usará la sesión actual.")
            }
            .font(DS.Fonts.sans(12))
            .foregroundStyle(DS.Colors.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Detect") { onDetect() }
                .buttonStyle(LLMActivateButton())
                .padding(.trailing, 6)
        }
        .frame(height: 38)
        .padding(.horizontal, 12)
        .background(DS.Colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(DS.Colors.lineSoft, lineWidth: 1))
    }
}

private struct LLMCLIActiveRow: View {
    let path: String
    let onTest: () -> Void
    let onDeactivate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.moss)
                .padding(.leading, 12)
            Group {
                Text("detectado en ").foregroundStyle(DS.Colors.ink3) +
                Text(path.isEmpty ? "/usr/local/bin/claude" : path).foregroundStyle(DS.Colors.mossInk)
            }
            .font(DS.Fonts.mono(11))
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Test") { onTest() }
                .buttonStyle(LLMGhostButton())
            Button("Change") { onDeactivate() }
                .buttonStyle(LLMGhostButton())
                .padding(.trailing, 6)
        }
        .frame(height: 38)
        .background(DS.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(hex: "DCE4CC"), lineWidth: 1))
    }
}

// MARK: - Toast

private struct LLMToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DS.Fonts.sans(12))
            .foregroundStyle(DS.Colors.paper)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(DS.Colors.ink)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Button styles

private struct LLMActivateButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.sans(12, weight: .medium))
            .foregroundStyle(DS.Colors.paper)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isEnabled ? DS.Colors.ink : DS.Colors.ink4)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct LLMGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.sans(11.5))
            .foregroundStyle(DS.Colors.ink3)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(DS.Colors.line, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
