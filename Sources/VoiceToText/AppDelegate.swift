import SwiftUI
import UserNotifications
import whisper

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let recorder = AudioRecorder()
    let transcriber = WhisperTranscriber()
    let postProcessor = TextPostProcessor()
    var hotkeyManager: HotkeyManager?
    var liveTask: Task<Void, Never>?
    private var downloadManager: ModelDownloadManager?
    private var settingsWindow: NSWindow?
    private var floatingWindows: [NSPanel] = []
    private var liveSessionText = ""
    private var recordingTimer: Task<Void, Never>?
    private var windowDelegate: SettingsWindowDelegate?

    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        downloadManager = ModelDownloadManager(appState: appState) { [weak self] model in
            await self?.loadModel(model)
        }
        appState.restore()
        setupHotkey()
        setupStatusItemRightClick()
        registerService()
        if !TextSimulator.hasAccessibilityPermission {
            TextSimulator.requestAccessibilityPermission()
        }
        Task { await loadModel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.save()
        liveTask?.cancel()
        recorder.shutdown()
        // Exit immediately to avoid ggml_abort during async teardown.
        // The OS reclaims all process memory — no leak.
        _exit(0)
    }

    func saveSettings() { appState.save() }

    private func outputText(_ text: String) {
        guard !text.isEmpty else { return }
        let processed = appState.applyReplacements(text)
        guard !processed.isEmpty else { return }
        let hasAccess = TextSimulator.hasAccessibilityPermission
        fputs("[Output] mode=\(appState.outputMode) access=\(hasAccess) text=\"\(processed.prefix(40))\"\n", stderr)
        switch appState.outputMode {
        case .typeText:
            if hasAccess {
                TextSimulator.simulateTyping(text: processed)
            } else {
                TextSimulator.requestAccessibilityPermission()
                TextSimulator.copyToClipboard(text: processed, autoPaste: true)
            }
        case .clipboard:
            TextSimulator.copyToClipboard(text: processed)
        }
    }

    private func playStartSound() { appState.startSound.play() }
    private func playStopSound() { appState.stopSound.play() }

    // MARK: - Recording Timer & Silence Detection

    private func startRecordingTimer() {
        appState.recordingSeconds = 0
        appState.audioLevel = 0
        appState.silenceCountdown = 0
        recordingTimer = Task {
            var ticks = 0
            var silenceTicks = 0
            let thresholdLevel = Float(appState.liveSilenceThreshold / Double(AudioConstants.maxExpectedEnergy))
            let maxSilenceTicks = max(1, Int(appState.liveSilenceTimeout / 0.2))
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
                ticks += 1
                appState.audioLevel = recorder.currentLevel
                if ticks % 5 == 0 {
                    appState.recordingSeconds += 1
                }
                if appState.mode == .batch {
                    if recorder.currentLevel < thresholdLevel {
                        silenceTicks += 1
                        let remaining = max(0, maxSilenceTicks - silenceTicks)
                        appState.silenceCountdown = Int(ceil(Double(remaining) * 0.2))
                        if silenceTicks >= maxSilenceTicks {
                            appState.silenceCountdown = 0
                            await stopBatchRecording()
                            return
                        }
                    } else {
                        silenceTicks = 0
                        appState.silenceCountdown = 0
                    }
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.cancel()
        recordingTimer = nil
        appState.silenceCountdown = 0
        if !recorder.isMonitoring { appState.audioLevel = 0 }
    }

    // MARK: - Level Monitoring (for Settings calibration)

    private var monitoringTimer: Task<Void, Never>?

    func startAudioMonitoring() {
        guard monitoringTimer == nil else { return }
        Task {
            let granted = await AudioRecorder.requestPermission()
            guard granted else { return }
            do {
                try recorder.startLevelMonitoring()
                monitoringTimer = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled else { return }
                        appState.audioLevel = recorder.currentLevel
                    }
                }
            } catch {
                appState.lastError = "Audio monitoring failed: \(error.localizedDescription)"
            }
        }
    }

    func stopAudioMonitoring() {
        monitoringTimer?.cancel()
        monitoringTimer = nil
        recorder.stopLevelMonitoring()
        if !appState.isRecording { appState.audioLevel = 0 }
    }

    // MARK: - Status Item Right-Click Menu

    private func setupStatusItemRightClick() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            // Detect right-click on the MenuBarExtra's status bar window
            if let window = event.window,
               String(describing: type(of: window)).contains("StatusBar") {
                self.showStatusItemMenu(from: event)
                return nil
            }
            return event
        }
    }

    private func showStatusItemMenu(from event: NSEvent) {
        let menu = NSMenu()

        let recordItem = NSMenuItem(
            title: appState.isRecording ? "Stop Recording" : "Start Recording",
            action: #selector(toggleRecordingFromMenu),
            keyEquivalent: ""
        )
        recordItem.target = self
        recordItem.isEnabled = appState.isModelLoaded && !appState.isTranscribing && !appState.isProcessing
        menu.addItem(recordItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let historyItem = NSMenuItem(title: "History", action: #selector(openHistoryFromMenu), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        // Show the menu at the status item location
        if let window = event.window {
            let locationInWindow = event.locationInWindow
            menu.popUp(positioning: nil, at: NSPoint(x: locationInWindow.x, y: 0), in: window.contentView)
        }
    }

    @objc private func toggleRecordingFromMenu() {
        Task { await toggleRecording() }
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func openHistoryFromMenu() {
        openHistory()
    }

    // MARK: - macOS Service

    private func registerService() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// Called by macOS when the user picks "EchoWrite — Transcribe" from a right-click menu.
    @objc func transcribeService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        Task { await toggleRecording() }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager = HotkeyManager { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.toggleRecording() }
        }
        hotkeyManager?.keyCode = appState.hotkeyKeyCode
        hotkeyManager?.modifiers = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
        hotkeyManager?.register()
    }

    func applyHotkey() {
        hotkeyManager?.keyCode = appState.hotkeyKeyCode
        hotkeyManager?.modifiers = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
    }

    // MARK: - Notifications

    private func sendNotification(text: String) {
        guard appState.notifyOnComplete,
              Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Transcription Complete"
            content.body = String(text.prefix(100))
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(req)
        }
    }

    // MARK: - Downloads (delegated to ModelDownloadManager)

    func downloadAndLoadModel(_ model: WhisperModel) {
        downloadManager?.download(model)
    }

    func cancelDownload() {
        downloadManager?.cancel()
    }

    // MARK: - Floating Recording Window

    private func showFloatingWindow() {
        guard appState.showFloatingWindow else { return }
        guard floatingWindows.isEmpty else {
            floatingWindows.forEach { $0.orderFront(nil) }
            return
        }

        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 50
        let gap: CGFloat = 4

        // Try to position left-aligned below the focused text input.
        // AX uses top-left origin; AppKit uses bottom-left. The main
        // screen (index 0) has origin at bottom-left and its height
        // equals the global coordinate space height.
        let placement: (origin: NSPoint, screen: NSScreen)? = {
            guard let axFrame = TextSimulator.focusedElementFrame(),
                  let mainScreen = NSScreen.screens.first else { return nil }

            let globalH = mainScreen.frame.height
            // Convert AX top-left coords to AppKit bottom-left coords
            let inputLeftX = axFrame.origin.x
            let inputBottomY = globalH - (axFrame.origin.y + axFrame.size.height)
            let panelY = inputBottomY - panelHeight - gap

            let panelOrigin = NSPoint(x: inputLeftX, y: panelY)

            // Find which screen contains this point
            guard let screen = NSScreen.screens.first(where: {
                $0.visibleFrame.contains(panelOrigin)
            }) else { return nil }

            return (panelOrigin, screen)
        }()

        // Input detected → single panel on that screen, left-aligned below input.
        // No input → default: one panel per screen, centered at bottom.
        let placements: [(NSPoint, NSScreen)]
        if let placement {
            placements = [(placement.origin, placement.screen)]
        } else {
            placements = NSScreen.screens.map { screen in
                let sf = screen.visibleFrame
                return (NSPoint(x: sf.midX - panelWidth / 2, y: sf.minY + 60), screen)
            }
        }

        for (origin, _) in placements {
            let view = FloatingRecordingView(appState: appState)

            let controller = NSHostingController(rootView: view)
            controller.view.wantsLayer = true
            controller.view.layer?.backgroundColor = .clear

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = controller
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false

            panel.setFrameOrigin(origin)

            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            floatingWindows.append(panel)
        }
    }

    private func hideFloatingWindow() {
        guard !floatingWindows.isEmpty else { return }
        for panel in floatingWindows {
            panel.close()
        }
        floatingWindows.removeAll()
    }

    // MARK: - Settings Window

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func deactivateAppIfNoWindows() {
        let hasVisible = settingsWindow?.isVisible ?? false
        if !hasVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func openSettings(section: SettingsSection = .general) {
        appState.selectedSettingsSection = section
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }
        let view = SettingsView(
            state: appState,
            onSave: { [weak self] in self?.appState.save() },
            onHotkeyChange: { [weak self] in self?.applyHotkey() },
            onPauseHotkey: { [weak self] in self?.hotkeyManager?.isEnabled = false },
            onResumeHotkey: { [weak self] in self?.hotkeyManager?.isEnabled = true },
            onStartMonitoring: { [weak self] in self?.startAudioMonitoring() },
            onStopMonitoring: { [weak self] in self?.stopAudioMonitoring() },
            onDownloadModel: { [weak self] model in self?.downloadAndLoadModel(model) },
            onLoadModel: { [weak self] model in
                guard let self else { return }
                Task { await self.loadModel(model) }
            },
            onUnloadModel: { [weak self] in
                guard let self else { return }
                Task { await self.unloadModel() }
            },
            onCancelDownload: { [weak self] in self?.cancelDownload() }
        )
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let windowWidth = screen.width * 3 / 5
        let windowHeight = screen.height * 0.75

        let delegate = SettingsWindowDelegate { [weak self] in self?.deactivateAppIfNoWindows() }
        windowDelegate = delegate

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "VoiceToText"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.minSize = NSSize(width: 500, height: 350)
        window.level = .normal
        window.delegate = delegate
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        window.center()
        window.makeKeyAndOrderFront(nil)
        activateApp()
        settingsWindow = window
    }

    func openHistory() {
        openSettings(section: .history)
    }

    // MARK: - Model Loading

    func loadModel(_ model: WhisperModel? = nil) async {
        let selected = model ?? appState.model
        await MainActor.run {
            appState.isModelLoaded = false
            appState.isLoadingModel = true
            appState.status = .idle
        }
        do {
            try await transcriber.loadModel(fileName: selected.fileName)
            await MainActor.run {
                appState.model = selected
                appState.isModelLoaded = true
                appState.isLoadingModel = false
                appState.lastError = nil
            }
        } catch {
            await MainActor.run {
                appState.isLoadingModel = false
                appState.lastError = error.localizedDescription
                appState.status = .error
            }
        }
    }

    func unloadModel() async {
        await transcriber.cleanup()
        appState.isModelLoaded = false
    }

    // MARK: - Recording

    func toggleRecording() async {
        guard !appState.isTranscribing, !appState.isProcessing, appState.isModelLoaded else { return }
        if appState.isRecording {
            if appState.mode == .live { await stopLiveRecording() }
            else { await stopBatchRecording() }
        } else {
            let granted = await AudioRecorder.requestPermission()
            guard granted else {
                appState.lastError = "Microphone permission denied"
                appState.status = .error
                return
            }
            do {
                playStartSound()
                try await Task.sleep(nanoseconds: 250_000_000)
                try recorder.startRecording()
                appState.status = .recording
                appState.lastError = nil
                startRecordingTimer()
                showFloatingWindow()
                if appState.mode == .live {
                    liveSessionText = ""
                    startLiveLoop()
                }
            } catch {
                appState.status = .error
                appState.lastError = error.localizedDescription
            }
        }
    }

    private func stopBatchRecording() async {
        stopRecordingTimer()
        let audioData = recorder.stopRecording()
        playStopSound()
        appState.status = .transcribing
        do {
            var text = try await transcriber.transcribe(
                audioData: audioData, language: appState.language.rawValue,
                translate: false,
                initialPrompt: appState.composedPrompt)
            text = await postProcessIfEnabled(text)
            hideFloatingWindow()
            outputText(text)
            appState.status = .idle
            appState.lastError = nil
            appState.addToHistory(text, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: text)
        } catch {
            hideFloatingWindow()
            appState.status = .error
            appState.lastError = error.localizedDescription
        }
    }

    // MARK: - LLM Post-Processing

    private var translateToLabel: String? {
        appState.llmTranslateLanguage?.label
    }

    private func postProcessIfEnabled(_ text: String) async -> String {
        guard appState.llmPostProcessEnabled,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        appState.status = .processing
        do {
            return try await postProcessor.process(
                text: text,
                provider: appState.llmProvider,
                model: appState.llmModel,
                stylePrompt: appState.llmStylePrompt,
                translateTo: translateToLabel
            )
        } catch {
            appState.lastError = "AI enhance failed: \(error.localizedDescription)"
            return text // fallback to original
        }
    }

    /// Post-process the accumulated live session text. Replaces liveSessionText in place.
    private func postProcessLiveSessionIfEnabled() async -> String {
        guard appState.llmPostProcessEnabled, !liveSessionText.isEmpty else { return liveSessionText }
        appState.status = .processing
        do {
            return try await postProcessor.process(
                text: liveSessionText,
                provider: appState.llmProvider,
                model: appState.llmModel,
                stylePrompt: appState.llmStylePrompt,
                translateTo: translateToLabel
            )
        } catch {
            appState.lastError = "AI enhance failed: \(error.localizedDescription)"
            return liveSessionText
        }
    }

    /// Non-isolated version for use from detached tasks
    nonisolated func postProcessLiveIfEnabled(_ text: String) async -> String {
        guard !text.isEmpty else { return text }
        let (enabled, provider, model, stylePrompt, translateTo) = await MainActor.run {
            (appState.llmPostProcessEnabled, appState.llmProvider, appState.llmModel, appState.llmStylePrompt, appState.llmTranslateLanguage?.label)
        }
        guard enabled else { return text }
        await MainActor.run { appState.status = .processing }
        do {
            return try await postProcessor.process(
                text: text, provider: provider, model: model, stylePrompt: stylePrompt, translateTo: translateTo
            )
        } catch {
            await MainActor.run { appState.lastError = "AI enhance failed: \(error.localizedDescription)" }
            return text
        }
    }

    // MARK: - Live Transcription

    private func startLiveLoop() {
        liveTask = Task.detached { [weak self] in
            var promptTokens: [whisper_token] = []
            var silenceSteps = 0
            let intervalNs: UInt64
            let overlapSamples: Int
            let silenceThreshold: Double
            let silenceTimeout: Double
            if let s = self {
                (intervalNs, overlapSamples, silenceThreshold, silenceTimeout) = await MainActor.run {
                    (UInt64(s.appState.liveChunkInterval * 1_000_000_000),
                     s.appState.liveOverlapMs * 16,
                     s.appState.liveSilenceThreshold,
                     s.appState.liveSilenceTimeout)
                }
            } else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled, let self else { return }
                let (language, prompt) = await MainActor.run {
                    (self.appState.language.rawValue, self.appState.composedPrompt)
                }
                let chunk = self.recorder.drainSamples(keeping: overlapSamples)
                guard !chunk.isEmpty else { continue }
                let energy = chunk.reduce(Float(0)) { $0 + abs($1) } / Float(chunk.count)
                guard energy > Float(silenceThreshold) else {
                    promptTokens.removeAll()
                    silenceSteps += 1
                    let maxSilenceSteps = Int(silenceTimeout / (Double(intervalNs) / 1_000_000_000))
                    if silenceSteps >= max(1, maxSilenceSteps) {
                        await MainActor.run {
                            self.stopRecordingTimer()
                            _ = self.recorder.stopRecording()
                            self.playStopSound()
                        }
                        let finalText = await MainActor.run { self.liveSessionText }
                        let processed = await self.postProcessLiveIfEnabled(finalText)
                        await MainActor.run {
                            if processed != self.liveSessionText, self.appState.outputMode == .typeText {
                                let oldLength = self.appState.applyReplacements(self.liveSessionText).count
                                TextSimulator.deleteCharacters(count: oldLength)
                                usleep(50_000)
                                self.outputText(processed)
                            }
                            self.hideFloatingWindow()
                            self.appState.status = .idle
                            self.appState.addToHistory(processed, durationSeconds: self.appState.recordingSeconds, translated: self.appState.llmTranslateLanguage != nil)
                            self.sendNotification(text: processed)
                        }
                        return
                    }
                    continue
                }
                silenceSteps = 0
                do {
                    let (text, tokens) = try await self.transcriber.transcribeLive(
                        audioData: chunk, language: language,
                        translate: false, promptTokens: promptTokens,
                        initialPrompt: prompt)
                    promptTokens = tokens
                    if !text.isEmpty {
                        await MainActor.run {
                            if !self.liveSessionText.isEmpty {
                                self.outputText(" ")
                                self.liveSessionText += " "
                            }
                            self.outputText(text)
                            self.liveSessionText += text
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.appState.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func stopLiveRecording() async {
        stopRecordingTimer()
        liveTask?.cancel()
        await liveTask?.value
        liveTask = nil
        playStopSound()
        let remaining = recorder.stopRecording()
        guard !remaining.isEmpty else {
            let finalText = await postProcessLiveSessionIfEnabled()
            if finalText != liveSessionText, appState.outputMode == .typeText {
                let oldLength = appState.applyReplacements(liveSessionText).count
                TextSimulator.deleteCharacters(count: oldLength)
                usleep(50_000)
                outputText(finalText)
            }
            hideFloatingWindow()
            appState.addToHistory(finalText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: finalText)
            appState.status = .idle
            return
        }
        appState.status = .transcribing
        do {
            let text = try await transcriber.transcribe(
                audioData: remaining, language: appState.language.rawValue,
                translate: false,
                initialPrompt: appState.composedPrompt)
            liveSessionText += text
            let finalText = await postProcessLiveSessionIfEnabled()
            if finalText != liveSessionText {
                let oldLength = appState.applyReplacements(liveSessionText).count
                TextSimulator.deleteCharacters(count: oldLength)
                usleep(50_000)
                outputText(finalText)
            } else {
                outputText(text)
            }
            hideFloatingWindow()
            appState.addToHistory(finalText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: finalText)
            appState.status = .idle
            appState.lastError = nil
        } catch {
            hideFloatingWindow()
            appState.addToHistory(liveSessionText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            appState.status = .error
            appState.lastError = error.localizedDescription
        }
    }
}

// MARK: - SettingsWindowDelegate

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
