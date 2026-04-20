import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colors: ThemeColors {
        switch self {
        case .light: return ThemeColors.light
        case .dark:  return ThemeColors.dark
        }
    }

    var preview: (Color, Color, Color) {
        (colors.accent, colors.floatingBackground, colors.floatingText)
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

struct ThemeColors {
    let accent: Color
    let floatingBackground: Color
    let floatingText: Color
    let floatingSecondary: Color
    let floatingBorder: Color
    let waveformColor: Color    // Paper uses a single waveform color (no 3-tier)
    let waveformLow: Color
    let waveformMid: Color
    let waveformHigh: Color
    let cardBackground: Color
    let cardBorder: Color
    let sidebarAccent: Color

    static let light = ThemeColors(
        accent: Color(hex: "2c5282"),
        floatingBackground: Color(hex: "ffffff"),
        floatingText: Color(hex: "1a1a1a"),
        floatingSecondary: Color(hex: "4a4a48"),
        floatingBorder: Color(hex: "ebe8df"),
        waveformColor: Color(hex: "1a1a1a"),
        waveformLow: Color(hex: "b8b5ad"),
        waveformMid: Color(hex: "2c5282").opacity(0.7),
        waveformHigh: Color(hex: "2c5282"),
        cardBackground: Color(hex: "ffffff"),
        cardBorder: Color(hex: "ebe8df"),
        sidebarAccent: Color(hex: "2c5282")
    )

    static let dark = ThemeColors(
        accent: Color(hex: "6b9ed4"),
        floatingBackground: Color(hex: "1a1a1a"),
        floatingText: Color(hex: "f7f5f0"),
        floatingSecondary: Color(hex: "b8b5ad"),
        floatingBorder: Color(hex: "333330"),
        waveformColor: Color(hex: "f7f5f0"),
        waveformLow: Color(hex: "4a4a48"),
        waveformMid: Color(hex: "6b9ed4").opacity(0.7),
        waveformHigh: Color(hex: "6b9ed4"),
        cardBackground: Color(hex: "2a2a28"),
        cardBorder: Color(hex: "3d3d3a"),
        sidebarAccent: Color(hex: "6b9ed4")
    )
}

// MARK: - Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = .light
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
