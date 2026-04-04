import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?
    var onPauseHotkey: (() -> Void)?
    var onResumeHotkey: (() -> Void)?
    var onStartMonitoring: (() -> Void)?
    var onStopMonitoring: (() -> Void)?
    var onDownloadModel: ((WhisperModel) -> Void)?
    var onLoadModel: ((WhisperModel) -> Void)?
    var onUnloadModel: (() -> Void)?
    var onCancelDownload: (() -> Void)?

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $state.selectedSettingsSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 180)
        } detail: {
            if state.selectedSettingsSection == .history {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(state.isRecording || state.isTranscribing)
            } else {
                ScrollView {
                    detailContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(state.isRecording || state.isTranscribing)
                }
            }
        }
        .onAppear {
            if state.selectedSettingsSection == .transcription { onStartMonitoring?() }
        }
        .onDisappear {
            onStopMonitoring?()
        }
        .onChange(of: state.selectedSettingsSection) { oldValue, newValue in
            if newValue == .transcription { onStartMonitoring?() }
            else if oldValue == .transcription { onStopMonitoring?() }
        }
        .onChange(of: state.language) { onSave() }
        .onChange(of: state.appTheme) { onSave() }
        .environment(\.themeColors, state.appTheme.colors)
        .preferredColorScheme(state.appTheme.preferredColorScheme)
        .onChange(of: state.outputMode) { onSave() }
        .onChange(of: state.startSound) { onSave() }
        .onChange(of: state.stopSound) { onSave() }
        .onChange(of: state.showFloatingWindow) { onSave() }
        .onChange(of: state.notifyOnComplete) { onSave() }
        .onChange(of: state.liveChunkInterval) { onSave() }
        .onChange(of: state.liveOverlapMs) { onSave() }
        .onChange(of: state.liveSilenceThreshold) { onSave() }
        .onChange(of: state.liveSilenceTimeout) { onSave() }
        .onChange(of: state.llmPostProcessEnabled) { onSave() }
        .onChange(of: state.llmProvider) { onSave() }
        .onChange(of: state.llmModel) { onSave() }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch state.selectedSettingsSection {
        case .general:
            GeneralPanel(state: state, onSave: onSave,
                         onHotkeyChange: onHotkeyChange,
                         onPauseHotkey: onPauseHotkey,
                         onResumeHotkey: onResumeHotkey,
                         onLoadModel: onLoadModel,
                         onUnloadModel: onUnloadModel)
        case .appearance:
            AppearancePanel(state: state, onSave: onSave)
        case .models:
            ModelsPanel(state: state,
                        onDownloadModel: onDownloadModel,
                        onLoadModel: onLoadModel,
                        onCancelDownload: onCancelDownload)
        case .transcription:
            TranscriptionPanel(state: state, onSave: onSave)
        case .replacements:
            ReplacementsPanel(state: state, onSave: onSave)
        case .llm:
            LLMPanel(state: state, onSave: onSave)
        case .tones:
            TonesPanel(state: state, onSave: onSave)
        case .appRules:
            AppRulesPanel(state: state, onSave: onSave)
        case .dashboard:
            DashboardPanel(state: state, onSave: onSave)
        case .history:
            HistoryView(state: state, onSave: onSave).padding(24)
        case .about:
            AboutPanel(state: state, onSave: onSave, onHotkeyChange: onHotkeyChange)
        }
    }
}
