import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?
    var onCancelHotkeyChange: (() -> Void)?
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
            SettingsSidebar(selection: $state.selectedSettingsSection, onClose: { state.showSettings = false })
                .frame(width: 180)

            Rectangle()
                .fill(DS.Colors.line)
                .frame(width: 1)

            ScrollView {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DS.Colors.paper)
            .disabled(state.isRecording || state.isTranscribing)
        }
        .preferredColorScheme(.light)
        .environment(\.themeColors, state.appTheme.colors)
        .onAppear {
            if state.selectedSettingsSection == .audio { onStartMonitoring?() }
        }
        .onDisappear { onStopMonitoring?() }
        .onChange(of: state.selectedSettingsSection) { oldValue, newValue in
            if newValue == .audio { onStartMonitoring?() }
            else if oldValue == .audio { onStopMonitoring?() }
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
            GeneralPanel(state: state, onSave: onSave)
        case .audio:
            TranscriptionPanel(state: state, onSave: onSave)
        case .modelos:
            ModelsPanel(state: state,
                        onDownloadModel: onDownloadModel,
                        onLoadModel: onLoadModel,
                        onCancelDownload: onCancelDownload)
        case .llm:
            LLMPanel(state: state, onSave: onSave)
        case .atajos:
            AtajosPanel(
                state: state,
                onSave: onSave,
                onHotkeyChange: onHotkeyChange,
                onCancelHotkeyChange: onCancelHotkeyChange,
                onPauseHotkey: onPauseHotkey,
                onResumeHotkey: onResumeHotkey
            )
        case .privacidad:
            AboutPanel(state: state, onSave: onSave, onHotkeyChange: onHotkeyChange)
        }
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Colors.ink3)
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.lineSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("SETTINGS")
                    .font(DS.Fonts.mono(10.5, weight: .medium))
                    .foregroundStyle(DS.Colors.ink4)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)

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

            Text("Tildo \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(DS.Fonts.mono(10.5))
                .foregroundStyle(DS.Colors.ink4)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
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
                Text(LocalizedStringKey(section.rawValue))
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
