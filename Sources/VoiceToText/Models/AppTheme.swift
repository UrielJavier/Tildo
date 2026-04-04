import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case midnight = "Midnight"
    case ocean = "Ocean"
    case forest = "Forest"
    case sunset = "Sunset"
    case rose = "Rose"
    case lavender = "Lavender"

    var id: String { rawValue }

    var colors: ThemeColors {
        switch self {
        case .system:   return ThemeColors.system
        case .light:    return ThemeColors.light
        case .dark:     return ThemeColors.dark
        case .midnight: return ThemeColors.midnight
        case .ocean:    return ThemeColors.ocean
        case .forest:   return ThemeColors.forest
        case .sunset:   return ThemeColors.sunset
        case .rose:     return ThemeColors.rose
        case .lavender: return ThemeColors.lavender
        }
    }

    var preview: (Color, Color, Color) {
        (colors.accent, colors.floatingBackground, colors.floatingText)
    }

    /// Which system appearance this theme is designed for.
    enum Appearance { case light, dark, any }

    var preferredAppearance: Appearance {
        switch self {
        case .system:               return .any
        case .light, .rose, .lavender: return .light
        case .dark, .midnight, .ocean, .forest, .sunset: return .dark
        }
    }

    /// Whether this theme has acceptable contrast for the given color scheme.
    func isCompatible(with scheme: ColorScheme) -> Bool {
        switch preferredAppearance {
        case .any:   return true
        case .light: return scheme == .light
        case .dark:  return scheme == .dark
        }
    }

    /// Forces the SwiftUI color scheme that ensures text contrast for this theme.
    /// nil means follow the system (used for the .system theme).
    var preferredColorScheme: ColorScheme? {
        switch preferredAppearance {
        case .light: return .light
        case .dark:  return .dark
        case .any:   return nil
        }
    }
}

struct ThemeColors {
    let accent: Color
    let floatingBackground: Color
    let floatingText: Color
    let floatingSecondary: Color
    let waveformLow: Color
    let waveformMid: Color
    let waveformHigh: Color
    let cardBackground: Color
    let cardBorder: Color
    let sidebarAccent: Color

    // MARK: - Presets

    static let system = ThemeColors(
        accent: .accentColor,
        floatingBackground: Color(NSColor.windowBackgroundColor),
        floatingText: Color(NSColor.labelColor),
        floatingSecondary: Color(NSColor.secondaryLabelColor),
        waveformLow: Color(NSColor.tertiaryLabelColor),
        waveformMid: .orange,
        waveformHigh: .red,
        cardBackground: Color(NSColor.controlBackgroundColor),
        cardBorder: Color(NSColor.separatorColor),
        sidebarAccent: .accentColor
    )

    static let light = ThemeColors(
        accent: Color(red: 0.2, green: 0.5, blue: 1.0),
        floatingBackground: .white,
        floatingText: Color(white: 0.15),
        floatingSecondary: Color(white: 0.5),
        waveformLow: Color(white: 0.78),
        waveformMid: .orange,
        waveformHigh: .red,
        cardBackground: Color(white: 0.97),
        cardBorder: Color(white: 0.9),
        sidebarAccent: Color(red: 0.2, green: 0.5, blue: 1.0)
    )

    static let dark = ThemeColors(
        accent: Color(red: 0.4, green: 0.7, blue: 1.0),
        floatingBackground: Color(white: 0.12),
        floatingText: Color(white: 0.92),
        floatingSecondary: Color(white: 0.55),
        waveformLow: Color(white: 0.35),
        waveformMid: .orange,
        waveformHigh: .red,
        cardBackground: Color(white: 0.14),
        cardBorder: Color(white: 0.22),
        sidebarAccent: Color(red: 0.4, green: 0.7, blue: 1.0)
    )

    static let midnight = ThemeColors(
        accent: Color(red: 0.55, green: 0.5, blue: 1.0),
        floatingBackground: Color(red: 0.08, green: 0.06, blue: 0.18),
        floatingText: Color(white: 0.9),
        floatingSecondary: Color(red: 0.6, green: 0.55, blue: 0.8),
        waveformLow: Color(red: 0.35, green: 0.3, blue: 0.55),
        waveformMid: Color(red: 0.7, green: 0.5, blue: 1.0),
        waveformHigh: Color(red: 1.0, green: 0.4, blue: 0.6),
        cardBackground: Color(red: 0.1, green: 0.08, blue: 0.2),
        cardBorder: Color(red: 0.2, green: 0.18, blue: 0.35),
        sidebarAccent: Color(red: 0.55, green: 0.5, blue: 1.0)
    )

    static let ocean = ThemeColors(
        accent: Color(red: 0.0, green: 0.7, blue: 0.8),
        floatingBackground: Color(red: 0.05, green: 0.15, blue: 0.22),
        floatingText: Color(red: 0.8, green: 0.95, blue: 1.0),
        floatingSecondary: Color(red: 0.4, green: 0.65, blue: 0.75),
        waveformLow: Color(red: 0.2, green: 0.45, blue: 0.55),
        waveformMid: Color(red: 0.0, green: 0.8, blue: 0.7),
        waveformHigh: Color(red: 1.0, green: 0.5, blue: 0.3),
        cardBackground: Color(red: 0.07, green: 0.17, blue: 0.24),
        cardBorder: Color(red: 0.15, green: 0.3, blue: 0.38),
        sidebarAccent: Color(red: 0.0, green: 0.7, blue: 0.8)
    )

    static let forest = ThemeColors(
        accent: Color(red: 0.3, green: 0.75, blue: 0.45),
        floatingBackground: Color(red: 0.08, green: 0.14, blue: 0.08),
        floatingText: Color(red: 0.85, green: 0.95, blue: 0.85),
        floatingSecondary: Color(red: 0.5, green: 0.7, blue: 0.5),
        waveformLow: Color(red: 0.25, green: 0.4, blue: 0.25),
        waveformMid: Color(red: 0.4, green: 0.8, blue: 0.4),
        waveformHigh: Color(red: 1.0, green: 0.6, blue: 0.2),
        cardBackground: Color(red: 0.1, green: 0.16, blue: 0.1),
        cardBorder: Color(red: 0.2, green: 0.3, blue: 0.2),
        sidebarAccent: Color(red: 0.3, green: 0.75, blue: 0.45)
    )

    static let sunset = ThemeColors(
        accent: Color(red: 1.0, green: 0.5, blue: 0.3),
        floatingBackground: Color(red: 0.18, green: 0.08, blue: 0.05),
        floatingText: Color(red: 1.0, green: 0.92, blue: 0.85),
        floatingSecondary: Color(red: 0.8, green: 0.55, blue: 0.4),
        waveformLow: Color(red: 0.5, green: 0.3, blue: 0.2),
        waveformMid: Color(red: 1.0, green: 0.65, blue: 0.3),
        waveformHigh: Color(red: 1.0, green: 0.3, blue: 0.3),
        cardBackground: Color(red: 0.2, green: 0.1, blue: 0.07),
        cardBorder: Color(red: 0.35, green: 0.2, blue: 0.15),
        sidebarAccent: Color(red: 1.0, green: 0.5, blue: 0.3)
    )

    static let rose = ThemeColors(
        accent: Color(red: 0.9, green: 0.4, blue: 0.55),
        floatingBackground: Color(red: 0.98, green: 0.95, blue: 0.96),
        floatingText: Color(red: 0.3, green: 0.15, blue: 0.2),
        floatingSecondary: Color(red: 0.6, green: 0.4, blue: 0.45),
        waveformLow: Color(red: 0.82, green: 0.72, blue: 0.75),
        waveformMid: Color(red: 0.9, green: 0.4, blue: 0.55),
        waveformHigh: Color(red: 1.0, green: 0.3, blue: 0.35),
        cardBackground: Color(red: 0.97, green: 0.93, blue: 0.94),
        cardBorder: Color(red: 0.88, green: 0.8, blue: 0.82),
        sidebarAccent: Color(red: 0.9, green: 0.4, blue: 0.55)
    )

    static let lavender = ThemeColors(
        accent: Color(red: 0.6, green: 0.5, blue: 0.9),
        floatingBackground: Color(red: 0.95, green: 0.94, blue: 0.98),
        floatingText: Color(red: 0.2, green: 0.15, blue: 0.35),
        floatingSecondary: Color(red: 0.5, green: 0.45, blue: 0.65),
        waveformLow: Color(red: 0.75, green: 0.72, blue: 0.85),
        waveformMid: Color(red: 0.6, green: 0.5, blue: 0.9),
        waveformHigh: Color(red: 0.9, green: 0.4, blue: 0.5),
        cardBackground: Color(red: 0.94, green: 0.93, blue: 0.97),
        cardBorder: Color(red: 0.82, green: 0.8, blue: 0.88),
        sidebarAccent: Color(red: 0.6, green: 0.5, blue: 0.9)
    )
}

// MARK: - Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors = .system
}

extension EnvironmentValues {
    var themeColors: ThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
