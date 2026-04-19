import ServiceManagement
import SwiftUI

struct GeneralPanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void
    var onHotkeyChange: (() -> Void)?
    var onPauseHotkey: (() -> Void)?
    var onResumeHotkey: (() -> Void)?
    var onLoadModel: ((WhisperModel) -> Void)?
    var onUnloadModel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHero(icon: "gearshape", title: "General", subtitle: "Language, output and shortcut preferences")

            settingsCard {
                settingsRow("Language", icon: "globe")
                Menu {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Button(lang.label) { state.language = lang }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(state.language.label)
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
                Text("The language spoken in your audio. \"Auto\" detects it automatically.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }

            settingsCard {
                settingsRow("Output mode", icon: "text.cursor")
                DSSegmentedControl(
                    options: OutputMode.allCases,
                    label: { $0.rawValue },
                    selection: $state.outputMode
                )
                Text("Type simulates keystrokes. Clipboard copies the text.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }

            settingsCard {
                settingsRow("Shortcut", icon: "command")
                HotkeyRecorderButton(
                    keyCode: $state.hotkeyKeyCode,
                    modifiers: $state.hotkeyModifiers,
                    onStartRecording: { onPauseHotkey?() },
                    onStopRecording: { onResumeHotkey?(); onSave(); onHotkeyChange?() }
                )
            }

            settingsCard {
                DSToggle(
                    title: "Launch at login",
                    icon: "power",
                    isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { v in try? v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                    )
                )
            }

            settingsCard {
                settingsRow("Memory", icon: "memorychip")
                if state.isLoadingModel {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading \(state.model.rawValue)...")
                            .font(DS.Fonts.sans(14))
                            .foregroundStyle(DS.Colors.oliveGray)
                    }
                } else if state.isModelLoaded {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(state.model.rawValue) loaded")
                                .font(DS.Fonts.sans(14))
                            Text("Using \(state.model.ramUsage) of RAM")
                                .font(DS.Fonts.sans(12))
                                .foregroundStyle(DS.Colors.stoneGray)
                        }
                        Spacer()
                        Button("Unload") { onUnloadModel?() }
                            .buttonStyle(.dsSecondary)
                    }
                } else {
                    HStack {
                        Text("No model in memory")
                            .font(DS.Fonts.sans(14))
                            .foregroundStyle(DS.Colors.stoneGray)
                        Spacer()
                        Button("Load") { onLoadModel?(state.model) }
                            .buttonStyle(.dsSecondary)
                    }
                }
                Text("Unloading frees RAM when you're not using transcription.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }
        }
        .padding(24)
    }
}
