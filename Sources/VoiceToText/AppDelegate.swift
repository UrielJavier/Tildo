import SwiftUI
import UserNotifications
import AVFoundation
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
    private var mainWindow: NSWindow?
    private var floatingWindows: [NSWindow] = []
    private var liveSessionText = ""
    private var recordingTimer: Task<Void, Never>?

    private var eventMonitor: Any?
    private var recordingTarget: RecordingTarget?
    private var recordingTargetURL: String?
    private var onboardingWindow: NSWindow?
    private var previousFrontmostApp: NSRunningApplication?
    private var workspaceObserver: Any?
    private var finishTransitionWork: DispatchWorkItem?
    private var cancelKeyLocalMonitor: Any?
    private var cancelKeyGlobalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        downloadManager = ModelDownloadManager(appState: appState) { [weak self] model in
            await self?.loadModel(model)
        }
        appState.restore()
        ensureValidModelSelected()
        applyDockPolicy()
        if appState.llmPostProcessEnabled && appState.llmProvider == .claudeCode {
            Task { await postProcessor.warmUp(provider: appState.llmProvider, model: appState.llmModel) }
        }
        setupHotkey()
        registerService()
        showOnboardingIfNeeded()
        if appState.hasCompletedOnboarding {
            openMainWindow()
        }
        Task { await loadModel() }
        setupFrontmostAppTracking()
    }

    private func setupFrontmostAppTracking() {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ownPid else { return }
            self?.previousFrontmostApp = app
        }
    }

    private func showOnboardingIfNeeded() {
        guard !appState.hasCompletedOnboarding else { return }

        let view = OnboardingView(
            appState: appState,
            onStartMonitoring: { [weak self] in self?.startAudioMonitoring() },
            onStopMonitoring: { [weak self] in self?.stopAudioMonitoring() },
            onPauseHotkey: { [weak self] in self?.hotkeyManager?.unregister() },
            onResumeHotkey: { [weak self] in self?.hotkeyManager?.register() },
            onDownloadModel: { [weak self] model in self?.downloadAndLoadModel(model) },
            onComplete: { [weak self] in
                guard let self else { return }
                appState.hasCompletedOnboarding = true
                appState.save()
                onboardingWindow?.close()
                onboardingWindow = nil
            }
        )

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to Tildo"
        window.styleMask = [.titled, .closable]
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 540, height: 440))
        window.center()
        window.makeKeyAndOrderFront(nil)
        activateApp()
        onboardingWindow = window
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
        #if DEBUG
        fputs("[Output] mode=\(appState.outputMode) access=\(hasAccess)\n", stderr)
        #endif
        switch appState.outputMode {
        case .typeText:
            if hasAccess {
                if let target = recordingTarget { TextSimulator.focusTarget(target) }
                TextSimulator.simulateTyping(text: processed)
            } else {
                // Without Accessibility permission, CGEventPost (used for typing AND Cmd+V paste)
                // will silently fail. Copy to clipboard as a reliable fallback and prompt the user.
                TextSimulator.copyToClipboard(text: processed, autoPaste: false)
                appState.lastError = "Accesibilidad no concedida — texto copiado al portapapeles. Pega con ⌘V. Ve a Ajustes > Privacidad > Accesibilidad para habilitar Tildo."
            }
        case .pasteAtCursor:
            if hasAccess {
                if let target = recordingTarget { TextSimulator.focusTarget(target) }
                TextSimulator.copyToClipboard(text: processed, autoPaste: true)
            } else {
                TextSimulator.copyToClipboard(text: processed, autoPaste: false)
                appState.lastError = "Accesibilidad no concedida — texto copiado al portapapeles. Pega con ⌘V."
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

    @objc private func toggleRecordingFromMenu() {
        Task { await toggleRecording() }
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func openHistoryFromMenu() {
        openHistory()
    }

    @objc private func openMainWindowFromMenu() {
        openMainWindow()
    }

    // MARK: - macOS Service

    private func registerService() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// Called by macOS when the user picks "Tildo — Transcribe" from a right-click menu.
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
            Task { @MainActor in
                if self.appState.triggerMode == .holdToTalk && self.appState.isRecording { return }
                await self.toggleRecording()
            }
        }
        hotkeyManager?.onKeyUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.appState.triggerMode == .holdToTalk,
                      self.appState.isRecording else { return }
                await self.toggleRecording()
            }
        }
        hotkeyManager?.keyCode = appState.hotkeyKeyCode
        hotkeyManager?.modifiers = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
        hotkeyManager?.register()
        setupCancelKeyMonitor()
    }

    func applyHotkey() {
        hotkeyManager?.keyCode = appState.hotkeyKeyCode
        hotkeyManager?.modifiers = NSEvent.ModifierFlags(rawValue: appState.hotkeyModifiers)
    }

    // MARK: - Cancel recording

    func cancelRecording() async {
        guard appState.isRecording else { return }
        finishTransitionWork?.cancel()
        finishTransitionWork = nil
        liveTask?.cancel()
        stopRecordingTimer()
        _ = recorder.stopRecording()
        hideFloatingWindow()
        appState.status = .idle
        appState.lastError = nil
    }

    func setupCancelKeyMonitor() {
        if let m = cancelKeyLocalMonitor { NSEvent.removeMonitor(m); cancelKeyLocalMonitor = nil }
        if let m = cancelKeyGlobalMonitor { NSEvent.removeMonitor(m); cancelKeyGlobalMonitor = nil }

        guard appState.cancelKeyCode != UInt16.max else { return }

        let keyCode = appState.cancelKeyCode
        let targetMods = NSEvent.ModifierFlags(rawValue: appState.cancelModifiers)
        let relevantMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control, .function]

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            guard event.keyCode == keyCode else { return }
            guard event.modifierFlags.intersection(relevantMask) == targetMods.intersection(relevantMask) else { return }
            Task { @MainActor in await self.cancelRecording() }
        }

        cancelKeyLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event); return event
        }
        cancelKeyGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { handler($0) }
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
            floatingWindows.forEach { $0.orderFrontRegardless() }
            return
        }

        let pillWidth: CGFloat = 280
        let pillHeight: CGFloat = 48
        // Extra transparent margin so the SwiftUI shadow isn't clipped by the window frame.
        let shadowPad: CGFloat = 16
        let panelWidth = pillWidth + shadowPad * 2
        let panelHeight = pillHeight + shadowPad * 2
        let gap: CGFloat = 4

        // Try to position below the focused text input (AX → AppKit coord conversion).
        let placement: (origin: NSPoint, screen: NSScreen)? = {
            guard let axFrame = TextSimulator.focusedElementFrame(),
                  let mainScreen = NSScreen.screens.first else { return nil }
            let globalH = mainScreen.frame.height
            let inputLeftX = axFrame.origin.x - shadowPad
            let inputBottomY = globalH - (axFrame.origin.y + axFrame.size.height)
            let panelOrigin = NSPoint(x: inputLeftX, y: inputBottomY - pillHeight - gap - shadowPad)
            guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(panelOrigin) }) else { return nil }
            return (panelOrigin, screen)
        }()

        // No AX focus → one pill per screen, just below the menu bar.
        let placements: [(NSPoint, NSScreen)]
        if let placement {
            placements = [(placement.origin, placement.screen)]
        } else {
            placements = NSScreen.screens.map { screen in
                let sf = screen.visibleFrame
                let origin = NSPoint(x: sf.midX - panelWidth / 2, y: sf.maxY - panelHeight - 8 + shadowPad)
                return (origin, screen)
            }
        }

        for (origin, _) in placements {
            // Wrap the pill in a padded container so shadows render within the window bounds.
            let view = FloatingRecordingView(appState: appState).padding(shadowPad)
            let hostingView = NSHostingView(rootView: AnyView(view))
            hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentView = hostingView
            panel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.popUpMenu.rawValue) + 2)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isReleasedWhenClosed = false
            panel.hasShadow = false
            panel.alphaValue = 1.0

            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
            floatingWindows.append(panel)
        }
    }

    private func hideFloatingWindow() {
        guard !floatingWindows.isEmpty else { return }
        for panel in floatingWindows { panel.close() }
        floatingWindows.removeAll()
        deactivateAppIfNoWindows()
    }

    // MARK: - Settings Window

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func deactivateAppIfNoWindows() {
        guard !appState.showInDock else { return }
        if !(mainWindow?.isVisible ?? false) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applyDockPolicy() {
        if appState.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            deactivateAppIfNoWindows()
        }
    }

    func openSettings(section: SettingsSection = .general) {
        appState.selectedSettingsSection = section
        openMainWindow()
        appState.showSettings = true
    }

    func openMainWindow(section: MainSection? = nil) {
        if let section { appState.selectedMainSection = section }
        if let w = mainWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }
        let view = MainWindowView(
            state: appState,
            onSave: { [weak self] in self?.appState.save() },
            onHotkeyChange: { [weak self] in self?.applyHotkey() },
            onCancelHotkeyChange: { [weak self] in self?.setupCancelKeyMonitor() },
            onPauseHotkey: { [weak self] in self?.hotkeyManager?.unregister() },
            onResumeHotkey: { [weak self] in self?.hotkeyManager?.register() },
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
        let delegate = SettingsWindowDelegate { [weak self] in self?.deactivateAppIfNoWindows() }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Tildo"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 860, height: 520)
        window.setContentSize(NSSize(width: 860, height: 600))
        window.delegate = delegate
        window.center()
        window.makeKeyAndOrderFront(nil)
        activateApp()
        mainWindow = window
    }

    func openHistory() {
        openMainWindow(section: .cuaderno)
    }

    // MARK: - Model Loading

    private func ensureValidModelSelected() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: appState.model.localPath) { return }
        // Current model file missing — pick the first downloaded model
        if let available = WhisperModel.allCases.first(where: { fileManager.fileExists(atPath: $0.localPath) }) {
            appState.model = available
        }
    }

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

    // MARK: - Silence Detection

    /// Returns true if the average energy of the audio samples is below the silence threshold.
    private func isSilent(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return true }
        let energy = samples.reduce(Float(0)) { $0 + abs($1) } / Float(samples.count)
        return energy < Float(appState.liveSilenceThreshold)
    }

    // MARK: - Recording

    private func scheduleFinish(delay: Double = 1.2) {
        finishTransitionWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hideFloatingWindow()
            self.appState.status = .idle
        }
        finishTransitionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func toggleRecording() async {
        finishTransitionWork?.cancel()
        finishTransitionWork = nil
        guard !appState.isTranscribing, !appState.isProcessing, appState.isModelLoaded else { return }
        // Capture frontmost app BEFORE any await — this is the moment closest to the hotkey press.
        let hotkeyFrontmost = NSWorkspace.shared.frontmostApplication
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
                let ownPid = ProcessInfo.processInfo.processIdentifier
                // Prefer AX-captured target; fall back to the app that was frontmost at hotkey time;
                // last resort: the workspace-tracked previous frontmost app.
                let fallbackApp = (hotkeyFrontmost?.processIdentifier != ownPid ? hotkeyFrontmost : nil)
                    ?? previousFrontmostApp
                recordingTarget = TextSimulator.captureCurrentTarget()
                    ?? fallbackApp.map { app in
                        RecordingTarget(
                            element: AXUIElementCreateApplication(app.processIdentifier),
                            pid: app.processIdentifier,
                            appName: app.localizedName ?? ""
                        )
                    }
recordingTargetURL = nil
                if let target = recordingTarget {
                    let appName = target.appName
                    Task { @MainActor in
                        // NSAppleScript must run on main thread
                        let url = TextSimulator.browserURL(for: appName)
                        self.recordingTargetURL = url
                    }
                }
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

        // Skip transcription if the recording is just silence
        guard !isSilent(audioData) else {
            hideFloatingWindow()
            appState.status = .idle
            return
        }

        appState.status = .transcribing
        do {
            var text = try await transcriber.transcribe(
                audioData: audioData, language: appState.language.rawValue,
                translate: false,
                initialPrompt: appState.composedPrompt)
            text = await postProcessIfEnabled(text, stylePrompt: resolvedStylePrompt())
            outputText(text)
            appState.status = .done
            appState.lastError = nil
            appState.addToHistory(text, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: text)
            scheduleFinish()
        } catch {
            appState.status = .error
            appState.lastError = error.localizedDescription
            scheduleFinish(delay: 2.0)
        }
    }

    // MARK: - LLM Post-Processing

    private var translateToLabel: String? {
        appState.llmTranslateLanguage?.label
    }

    private func resolvedStylePrompt() -> String {
        let appName = recordingTarget?.appName ?? ""
        let prompt = appState.resolveStylePrompt(appName: appName, url: recordingTargetURL)
        // Update the tone name shown in the floating pill to reflect the per-app resolved tone.
        let resolvedName = appState.appRules
            .first(where: { $0.isEnabled && $0.appName.lowercased() == appName.lowercased() })
            .flatMap { rule in appState.tones.first(where: { $0.id == rule.toneId }) }?.name
            ?? appState.tones.first(where: { $0.id == appState.defaultToneId })?.name
        appState.activeToneNameForRecording = resolvedName
        return prompt
    }

    private func postProcessIfEnabled(_ text: String, stylePrompt: String) async -> String {
        guard appState.llmPostProcessEnabled,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        appState.status = .processing
        do {
            return try await postProcessor.process(
                text: text,
                provider: appState.llmProvider,
                model: appState.llmModel,
                stylePrompt: stylePrompt,
                translateTo: translateToLabel
            )
        } catch {
            appState.lastError = "AI enhance failed: \(error.localizedDescription)"
            return text
        }
    }

    /// Post-process the accumulated live session text.
    private func postProcessLiveSessionIfEnabled(stylePrompt: String) async -> String {
        guard appState.llmPostProcessEnabled, !liveSessionText.isEmpty else { return liveSessionText }
        appState.status = .processing
        do {
            return try await postProcessor.process(
                text: liveSessionText,
                provider: appState.llmProvider,
                model: appState.llmModel,
                stylePrompt: stylePrompt,
                translateTo: translateToLabel
            )
        } catch {
            appState.lastError = "AI enhance failed: \(error.localizedDescription)"
            return liveSessionText
        }
    }

    /// Non-isolated version for use from detached tasks.
    nonisolated func postProcessLiveIfEnabled(_ text: String, stylePrompt: String) async -> String {
        guard !text.isEmpty else { return text }
        let (enabled, provider, model, translateTo) = await MainActor.run {
            (appState.llmPostProcessEnabled, appState.llmProvider, appState.llmModel, appState.llmTranslateLanguage?.label)
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
        let stylePrompt = resolvedStylePrompt()
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
                        let processed = await self.postProcessLiveIfEnabled(finalText, stylePrompt: stylePrompt)
                        await MainActor.run {
                            if processed != self.liveSessionText, self.appState.outputMode == .typeText {
                                let oldLength = self.appState.applyReplacements(self.liveSessionText).count
                                if let target = self.recordingTarget { TextSimulator.focusTarget(target) }
                                TextSimulator.deleteCharacters(count: oldLength)
                                usleep(50_000)
                                self.outputText(processed)
                            }
                            self.appState.status = .done
                            self.appState.addToHistory(processed, durationSeconds: self.appState.recordingSeconds, translated: self.appState.llmTranslateLanguage != nil)
                            self.sendNotification(text: processed)
                            self.scheduleFinish()
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
        let stylePrompt = resolvedStylePrompt()
        let remaining = recorder.stopRecording()
        // Skip transcription of remaining audio if empty or silent
        guard !remaining.isEmpty, !isSilent(remaining) else {
            let finalText = await postProcessLiveSessionIfEnabled(stylePrompt: stylePrompt)
            if finalText != liveSessionText, appState.outputMode == .typeText {
                let oldLength = appState.applyReplacements(liveSessionText).count
                if let target = recordingTarget { TextSimulator.focusTarget(target) }
                TextSimulator.deleteCharacters(count: oldLength)
                usleep(50_000)
                outputText(finalText)
            }
            appState.addToHistory(finalText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: finalText)
            appState.status = .done
            scheduleFinish()
            return
        }
        appState.status = .transcribing
        do {
            let text = try await transcriber.transcribe(
                audioData: remaining, language: appState.language.rawValue,
                translate: false,
                initialPrompt: appState.composedPrompt)
            liveSessionText += text
            let finalText = await postProcessLiveSessionIfEnabled(stylePrompt: stylePrompt)
            if finalText != liveSessionText {
                let oldLength = appState.applyReplacements(liveSessionText).count
                if let target = recordingTarget { TextSimulator.focusTarget(target) }
                TextSimulator.deleteCharacters(count: oldLength)
                usleep(50_000)
                outputText(finalText)
            } else {
                outputText(text)
            }
            appState.addToHistory(finalText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            sendNotification(text: finalText)
            appState.status = .done
            appState.lastError = nil
            scheduleFinish()
        } catch {
            appState.addToHistory(liveSessionText, durationSeconds: appState.recordingSeconds, translated: appState.llmTranslateLanguage != nil)
            appState.status = .error
            appState.lastError = error.localizedDescription
            scheduleFinish(delay: 2.0)
        }
    }
}

// MARK: - SettingsWindowDelegate

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

// NSHostingView subclass that lets isMovableByWindowBackground work
// from any point on the pill, not just where SwiftUI draws content.
final class MovableFloatingHostingView: NSHostingView<FloatingRecordingView> {
    override var mouseDownCanMoveWindow: Bool { true }
}
