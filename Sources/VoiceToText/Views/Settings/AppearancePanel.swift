import SwiftUI

struct AppearancePanel: View {
    @Bindable var state: AppState
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Appearance", subtitle: "Customize the look and feel of the app")

            settingsCard {
                settingsRow("Theme", icon: "paintbrush")
                ThemeGrid(selected: $state.appTheme, onSave: onSave)
            }

            settingsCard {
                settingsRow("Preview", icon: "eye")
                ThemePreview(theme: state.appTheme.colors)
            }
        }
        .padding(24)
    }
}

private struct ThemeGrid: View {
    @Binding var selected: AppTheme
    let onSave: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                let compatible = theme.isCompatible(with: colorScheme)
                ThemeCell(theme: theme, isSelected: selected == theme, disabled: !compatible) {
                    selected = theme
                    onSave()
                }
            }
        }
    }
}

private struct ThemeCell: View {
    let theme: AppTheme
    let isSelected: Bool
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Color swatch
                HStack(spacing: 0) {
                    theme.colors.floatingBackground
                    theme.colors.accent
                    theme.colors.cardBackground
                }
                .frame(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? theme.colors.accent : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

                Text(theme.rawValue)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? theme.colors.accent.opacity(0.1) : Color.clear)
            )
            .opacity(disabled ? 0.35 : 1.0)
            .overlay(
                Group {
                    if disabled {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1, antialiased: true)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(disabled ? "Poor contrast in current appearance mode" : "")
    }
}

private struct ThemePreview: View {
    let theme: ThemeColors

    var body: some View {
        // Floating window preview
        HStack(spacing: 10) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)

            // Mini waveform
            HStack(spacing: 1.5) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i > 9 ? theme.waveformHigh : i > 6 ? theme.waveformMid : theme.waveformLow)
                        .frame(width: 2, height: CGFloat.random(in: 3...14))
                }
            }
            .frame(height: 14)

            Text("01:23")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.floatingSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.floatingBackground)
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
