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
        HStack(spacing: 0) {
            SettingsSidebar(selection: $state.selectedSettingsSection)
                .frame(width: 200)

            Rectangle()
                .fill(DS.Colors.line)
                .frame(width: 1)

            Group {
                if state.selectedSettingsSection == .history {
                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        detailContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(DS.Colors.paper)
            .disabled(state.isRecording || state.isTranscribing)
        }
        .preferredColorScheme(.light)
        .environment(\.themeColors, state.appTheme.colors)
        .onAppear {
            if state.selectedSettingsSection == .transcription { onStartMonitoring?() }
        }
        .onDisappear { onStopMonitoring?() }
        .onChange(of: state.selectedSettingsSection) { oldValue, newValue in
            if newValue == .transcription { onStartMonitoring?() }
            else if oldValue == .transcription { onStopMonitoring?() }
        }
        .onChange(of: state.language) { onSave() }
        .onChange(of: state.appTheme) { onSave() }
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
        case .ai:
            AIPanel(state: state, onSave: onSave)
        case .dashboard:
            DashboardPanel(state: state, onSave: onSave)
        case .history:
            HistoryView(state: state, onSave: onSave).padding(24)
        case .about:
            AboutPanel(state: state, onSave: onSave, onHotkeyChange: onHotkeyChange)
        }
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand header
            HStack(spacing: 6) {
                Text("∼")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.moss)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tildo")
                        .font(DS.Fonts.sans(13, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink)
                    Text("Settings")
                        .font(DS.Fonts.sans(10.5))
                        .foregroundStyle(DS.Colors.ink3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Rectangle()
                .fill(DS.Colors.line)
                .frame(height: 1)
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                ForEach(SettingsSection.allCases) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selection == section,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .background(DS.Colors.panel)
    }
}

private struct SidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.ink3)
                    .frame(width: 16, alignment: .center)
                Text(section.rawValue)
                    .font(DS.Fonts.sans(12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.ink2)
                Spacer()
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(height: 32)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.paper)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.Colors.lineSoft)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
