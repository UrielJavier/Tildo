import SwiftUI

struct AppearancePanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHero(icon: "paintbrush", title: "Appearance", subtitle: "Floating window style, sounds, and visual feedback")

            settingsCard {
                settingsRow("Floating window theme", icon: "rectangle.on.rectangle")
                ThemePicker(selected: $state.appTheme, onSave: onSave)
            }

            settingsCard {
                settingsRow("Sounds", icon: "speaker.wave.2")
                SoundPicker(label: "Start", icon: "play.circle", selection: $state.startSound)
                DSDivider()
                SoundPicker(label: "Stop", icon: "stop.circle", selection: $state.stopSound)
                Text("Set to None to disable sound feedback.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }

            settingsCard {
                DSToggle(title: "Show floating window while recording", icon: "rectangle.on.rectangle", isOn: $state.showFloatingWindow)
                Text("Displays a small always-on-top overlay with timer and audio waveform while recording.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)

                DSDivider()

                DSToggle(title: "Notify on completion", icon: "bell", isOn: $state.notifyOnComplete)
                Text("Shows a system notification when transcription finishes.")
                    .font(DS.Fonts.sans(12))
                    .foregroundStyle(DS.Colors.stoneGray)
            }
        }
        .padding(24)
    }
}

private struct ThemePicker: View {
    @Binding var selected: AppTheme
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                ThemeCard(theme: theme, isSelected: selected == theme) {
                    selected = theme
                    onSave()
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private let barHeights: [CGFloat] = [4, 8, 12, 9, 14, 7, 10, 5]

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    HStack(spacing: 1.5) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { i, h in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(i > 5 ? theme.colors.waveformHigh : i > 3 ? theme.colors.waveformMid : theme.colors.waveformLow)
                                .frame(width: 2, height: h)
                        }
                    }
                    .frame(height: 14)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.colors.floatingBackground)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                )

                Text(theme.rawValue)
                    .font(DS.Fonts.sans(13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? DS.Colors.ink : DS.Colors.oliveGray)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? DS.Colors.warmSand : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        isSelected ? DS.Colors.moss : DS.Colors.borderCream,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
